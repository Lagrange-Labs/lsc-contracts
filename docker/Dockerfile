FROM ethereum/client-go

EXPOSE 8545

COPY ./geth_db /geth_db

ENTRYPOINT ["geth"]
CMD ["--rpc.allow-unprotected-txs", "--http", "--http.addr", "0.0.0.0","--http.corsdomain", "*", "--http.vhosts" ,"*", "--ws", "--ws.origins", "*", "--ws.addr", "0.0.0.0", "--dev", "--datadir", "/geth_db"]