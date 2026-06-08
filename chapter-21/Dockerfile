FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y nginx && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY html/ /var/www/html/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
