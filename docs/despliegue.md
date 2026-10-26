# Despliegue

La API corre en tres contenedores con `docker compose`: PostgreSQL, la API y Caddy, que pone HTTPS con certificado automático de Let's Encrypt. Los datos viajan por internet, así que la app solo debe hablar con el servidor por HTTPS.

## Qué hace falta

1. Un servidor Linux pequeño (1 GB de memoria alcanza) con Docker y el plugin `docker compose`.
2. Un nombre de dominio que apunte a la IP del servidor. Si no se quiere pagar uno, sirve un subdominio gratis de [DuckDNS](https://www.duckdns.org).
3. Los puertos 80 y 443 abiertos hacia el servidor.

## Primera vez

```bash
git clone https://github.com/Rafaariasxd/granja-app.git
cd granja-app
cp .env.example .env              # poner una clave larga en POSTGRES_PASSWORD y el dominio en DOMINIO
docker compose up -d --build
docker compose exec api python -m app.crear_admin    # primer administrador
```

Al arrancar, la API aplica sola las migraciones (`alembic upgrade head`). Se comprueba con `https://DOMINIO/salud`.

## Asistente de las aves

El asistente usa la capa gratuita de Gemini. Se saca una clave en [Google AI Studio](https://aistudio.google.com/apikey) y se pone en `GEMINI_API_KEY` dentro del `.env`. La clave queda solo en el servidor: la app nunca la ve. Sin clave, la app avisa que el asistente no está configurado y todo lo demás funciona igual. El modelo se cambia con `GEMINI_MODELO`.

## Actualizar

```bash
git pull
docker compose up -d --build
```

## Copia de seguridad

Los datos están en el volumen `datos`. Una copia a un archivo:

```bash
docker compose exec -T db pg_dump -U granja granja | gzip > granja-$(date +%F).sql.gz
```

Conviene programarla cada noche con `cron` y guardar las copias fuera del servidor. Restaurar:

```bash
gunzip -c granja-2026-10-25.sql.gz | docker compose exec -T db psql -U granja granja
```

## La app

La dirección del servidor se fija al compilar:

```bash
flutter build apk --release --dart-define=API_URL=https://DOMINIO
```
