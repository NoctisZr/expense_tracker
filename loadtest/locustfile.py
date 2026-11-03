"""
Prueba de carga de la sincronización de pareja (Supabase) con Locust.

Cada "usuario virtual" crea DOS sesiones anónimas (A y B), forma una pareja y
luego imita lo que hace la app: A sube gastos cifrados, B descarga novedades y
consulta los miembros. Además comprueba el AISLAMIENTO: una pareja nunca debe
poder leer los datos de otra.

USO (solo contra un proyecto de PRUEBAS, nunca contra el de verdad):
    pip install locust
    export SUPABASE_URL="https://TU-PROYECTO-DE-PRUEBAS.supabase.co"
    export SUPABASE_KEY="sb_publishable_..."
    locust -f loadtest/locustfile.py --headless -u 10 -r 1 -t 2m --csv loadtest/resultados

Lee el p95 y el p99, no solo el promedio (ver loadtest/README.md).
"""
import base64
import os
import random
import string
import time

from locust import HttpUser, between, task

URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
KEY = os.environ.get("SUPABASE_KEY", "")


def rand(n):
    return "".join(random.choices(string.ascii_lowercase + string.digits, k=n))


def blob(size):
    return base64.b64encode(os.urandom(size)).decode()


class CoupleUser(HttpUser):
    host = URL
    wait_time = between(1, 3)

    # Parejas de todos los usuarios virtuales (para probar el aislamiento).
    couples = []

    def on_start(self):
        if not URL or not KEY:
            raise SystemExit("Falta SUPABASE_URL o SUPABASE_KEY")
        self.a = self._signup("auth signup A")
        self.b = self._signup("auth signup B")
        self.invite = "lt-" + rand(32)  # el prefijo 'lt-' permite limpiar después
        r = self.client.post(
            "/rest/v1/rpc/create_couple",
            json={"p_invite_hash": self.invite},
            headers=self._h(self.a),
            name="rpc create_couple",
        )
        self.cid = r.json()
        self.client.post(
            "/rest/v1/rpc/join_couple",
            json={"p_invite_hash": self.invite},
            headers=self._h(self.b),
            name="rpc join_couple",
        )
        CoupleUser.couples.append(self.cid)
        self.counter = 0
        self.since = None

    # -- utilidades ---------------------------------------------------------
    def _h(self, session, extra=None):
        h = {
            "apikey": KEY,
            "Authorization": "Bearer " + session["token"],
            "Content-Type": "application/json",
        }
        if extra:
            h.update(extra)
        return h

    def _signup(self, name):
        """Sesión anónima. Reintenta si el servidor limita los registros (429)."""
        for attempt in range(6):
            with self.client.post(
                "/auth/v1/signup",
                json={"data": {}},
                headers={"apikey": KEY},
                name=name,
                catch_response=True,
            ) as r:
                if r.status_code == 200:
                    j = r.json()
                    return {"token": j["access_token"], "uid": j["user"]["id"]}
                r.failure(f"signup {r.status_code} (¿límite de registros anónimos?)")
            time.sleep(2 ** attempt)
        raise SystemExit("No se pudo crear la sesión: sube el límite de registros anónimos del proyecto de pruebas")

    # -- lo que hace la app --------------------------------------------------
    @task(3)
    def push(self):
        """A sube 20 gastos cifrados (como el 'subir' de la app)."""
        rows = []
        for _ in range(20):
            self.counter += 1
            rows.append(
                {
                    "couple_id": self.cid,
                    "id": f"{self.a['uid']}:expense:{self.counter}",
                    "kind": "expense",
                    "payload": blob(300),
                    "nonce": blob(12),
                    "deleted": False,
                }
            )
        self.client.post(
            "/rest/v1/shared_items?on_conflict=couple_id,id",
            json=rows,
            headers=self._h(self.a, {"Prefer": "resolution=merge-duplicates,return=minimal"}),
            name="push 20 filas",
        )

    @task(5)
    def pull(self):
        """B descarga las novedades (como el 'bajar' de la app)."""
        params = {
            "select": "id,kind,payload,nonce,deleted,updated_at",
            "couple_id": f"eq.{self.cid}",
            "author_id": f"neq.{self.b['uid']}",
            "order": "updated_at.asc,id.asc",
            "limit": "500",
        }
        if self.since:
            params["updated_at"] = f"gte.{self.since}"
        with self.client.get(
            "/rest/v1/shared_items", params=params, headers=self._h(self.b), name="pull", catch_response=True
        ) as r:
            if r.status_code == 200:
                rows = r.json()
                if rows:
                    self.since = rows[-1]["updated_at"]
            else:
                r.failure(f"pull {r.status_code}")

    @task(1)
    def members(self):
        self.client.get(
            "/rest/v1/couple_members",
            params={"select": "user_id", "couple_id": f"eq.{self.cid}"},
            headers=self._h(self.b),
            name="miembros",
        )

    @task(1)
    def isolation(self):
        """Una pareja NO debe leer los datos de otra: debe volver una lista vacía."""
        others = [c for c in CoupleUser.couples if c != self.cid]
        if not others:
            return
        other = random.choice(others)
        with self.client.get(
            "/rest/v1/shared_items",
            params={"select": "id", "couple_id": f"eq.{other}", "limit": "5"},
            headers=self._h(self.b),
            name="aislamiento (debe ser vacío)",
            catch_response=True,
        ) as r:
            if r.status_code == 200 and r.json():
                r.failure("¡AISLAMIENTO ROTO! Se leyeron datos de otra pareja")
            else:
                r.success()
