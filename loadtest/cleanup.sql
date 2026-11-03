-- Limpieza después de una prueba de carga.
-- ⚠️ EJECÚTALO SOLO EN EL PROYECTO DE PRUEBAS, nunca en el de verdad.

-- Borra las parejas de prueba (las crea el script con huella que empieza por 'lt-');
-- los miembros y los datos se borran en cascada.
delete from public.couples where invite_hash like 'lt-%';

-- Borra los usuarios anónimos creados durante la prueba (solo existen por la prueba en este proyecto).
delete from auth.users where is_anonymous = true and created_at > now() - interval '1 day';
