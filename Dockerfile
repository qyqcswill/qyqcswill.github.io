FROM nginx
RUN sed 

COPY public/ /usr/share/nginx/html/

ENTRYPOINT ["nginx", "-g", "daemon off;"]
