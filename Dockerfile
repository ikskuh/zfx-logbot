FROM nickblah/lua:5.1.5-luarocks-alpine
RUN apk add gcc bsd-compat-headers m4 sqlite libc-dev sqlite-dev libressl-dev make bash

RUN luarocks install luasocket
RUN luarocks install sqlite3
RUN luarocks install http

WORKDIR /opt/logbot
VOLUME /mnt/

COPY irc/ ./irc/
COPY data/ ./data/
COPY *.lua ./
COPY config.lua .

RUN ls 

CMD [ "lua", "zfxlogger.lua" ]
# CMD [ "nc", "-l", "8000" ]
