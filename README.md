# Enrutador Local

Servicio que levanta un nginx local (en docker) para mapear los contenderoes que se publican en un dns más óptimo y otros servicios que se necesiten (más allá de contenedores docker)

Utilizar el docker de nuestro equipo local
```bash
eval $(minikube docker-env -u)
```
*(La -u significa unset o desconfigurar).*

Se puede levantare un docker a través de *docker run* o hacer un docker compose.

### docker run
Luego habría que montar un 'online' para poder reflejar los cambios aplicados al instante. Aún así, será necesario reiniciar el servicio.

```bash
docker run -d \
  --name local-proxy \
  -p 80:80 \
  --mount type=bind,source="$(pwd)"/conf,target=/etc/nginx/conf.d \
  --add-host=host.docker.internal:host-gateway \
  nginx:latest
```

```bash
sudo mount --bind /mnt/a/Documentos/Code/nginx/conf /etc/nginx/conf.d
```

Recargar el servicio
```bash
docker exec local-proxy nginx -s reload
```

Para saber si el montaje es a través de un volumen o un mount
```bash
docker inspect local-proxy --format='{{json .Mounts}}' | jq
```

### docker compose

se editará un fichero docker-compose. En lugar de crear un mount se creará un volumen directamente.

```yml
services:
  nginx-proxy:
    image: nginx:latest
    container_name: local-proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./conf:/etc/nginx/conf.d:ro
      - ./generate_index.sh:/generate_index.sh:ro
      - ./start-nginx-with-refresh.sh:/start-nginx-with-refresh.sh:ro
    command: ["/bin/sh", "/start-nginx-with-refresh.sh"]
    environment:
      - REFRESH_SECONDS=21600
    healthcheck:
      test: ["CMD-SHELL", "nginx -t >/dev/null 2>&1 && [ -f /var/run/nginx.pid ] && kill -0 $$(cat /var/run/nginx.pid)"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 15s
    extra_hosts:
    # Esto permite que el contenedor reconozca 'host.docker.internal' en Linux
      - "host.docker.internal:host-gateway"
    restart: always
```

### Índice automático en nginx.local

- El bloque principal de `conf/default.conf` responde para `nginx.local`.
- En cada arranque del contenedor, `generate_index.sh` escanea los `server_name` de `conf/*.conf` y genera `/usr/share/nginx/html/index.html`.
- Un script interno (`start-nginx-with-refresh.sh`) vuelve a generar el índice cada 6 horas y ejecuta `nginx -s reload` sin reiniciar el contenedor.
- Si añades un nuevo `server` con `server_name`, aparecerá automáticamente en `http://nginx.local` en el siguiente ciclo (o al hacer `nginx -s reload`).

- Es necesario añadir la url en el fichero [host](../../../../../etc/hosts)

Intervalo configurable:
- Por defecto son `21600` segundos (6h).
- Puedes cambiarlo añadiendo `REFRESH_SECONDS` en el servicio de `docker-compose.yml`.

Healthcheck:
- Valida que la config de Nginx sea correcta (`nginx -t`) y que el proceso principal siga vivo.
- Permite ver estado `healthy`/`unhealthy` del contenedor.

Levantar/recrear:

```bash
docker compose up -d --force-recreate
```

Ver estado healthcheck:

```bash
docker ps
docker inspect local-proxy --format='{{json .State.Health}}' | jq
```


Para ver el servicio
```bash
#Acceder a contenedor
docker exec -it local-proxy /bin/sh
# Ve estado servicio
nginx
```

Recargar el servicio
```bash
docker exec local-proxy nginx -s reload
```

Ver los Logs
```bash
docker logs local-proxy
```

Fichero de configuracion de Nginx en [default.conf](./conf/default.conf)


# Troubleshoting

Es posible que al tratar de levantar el conteneder de un error indicando que el pueto 80 est'a ya en uso.
En algunos SO, se levanta un servicio de pruebas web en ese puerto.
En ubuntu, es Apache2
```log
Error response from daemon: failed to set up container networking: driver failed programming external connectivity on endpoint local-proxy (8e24fa4fe2e7a47f24a57ae5d0572f01cc8314d4f996f457b61ae30b5b05a5e9): failed to bind host port 0.0.0.0:80/tcp: address already in use
```


```bash
sudo systemctl stop apache2
#opcional permanente: 
sudo systemctl disable apache2
```

Para restaurar Apache cuando dejes de usar este proxy:
```bash
sudo systemctl enable apache2
sudo systemctl start apache2
sudo systemctl status apache2 --no-pager
```