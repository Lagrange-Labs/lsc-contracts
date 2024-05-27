FROM ethereum/client-go:v1.12.0

EXPOSE 8545

COPY ./geth_db /geth_db

ENTRYPOINT ["geth"]
CMD ["--rpc.allow-unprotected-txs", "--http", "--http.addr", "0.0.0.0","--http.corsdomain", "*", "--http.vhosts" ,"*", "--ws", "--ws.origins", "*", "--ws.addr", "0.0.0.0", "--dev", "--dev.period", "1", "--datadir", "--gcmode", "archive", "/geth_db"]