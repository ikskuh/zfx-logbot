FROM nickblah/lua:5.1.5-luarocks-alpine
RUN apk add gcc
RUN apk add sqlite
RUN apk add libc-dev
RUN apk add sqlite-dev
RUN apk add libressl-dev
RUN apk add make

RUN luarocks install luasocket
RUN luarocks install sqlite3
RUN apk add bsd-compat-headers
RUN apk add m4
RUN luarocks install http

WORKDIR /opt/logbot
VOLUME /mnt/

COPY irc/ ./irc/
COPY data/ ./data/
COPY *.lua ./
COPY config.lua .

RUN ls 

CMD [ "lua", "zfxlogger.lua" ]


RUN apk add bash