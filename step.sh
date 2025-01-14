#!/bin/bash
set -eu

echo "Configs:"
echo "host: $host"
echo "port: $port"
echo "proto: $proto"
echo "ca_crt: $(if [ ! -z "$ca_crt" ]; then echo "***"; fi)"
echo "ta_key: $(if [ ! -z "$ta_key" ]; then echo "***"; fi)"
echo "client_crt: $(if [ ! -z "$client_crt" ]; then echo "***"; fi)"
echo "client_key: $(if [ ! -z "$client_key" ]; then echo "***"; fi)"
echo ""

log_path=$(mktemp)

envman add --key "OPENVPN_LOG_PATH" --value "$log_path"
echo "Log path exported (\$OPENVPN_LOG_PATH=$log_path)"
echo ""

case "$OSTYPE" in
  linux*)
    echo "Configuring for Ubuntu"

    echo ${ca_crt} | base64 -d > /etc/openvpn/ca.crt
    echo ${ta_key} | base64 -d > /etc/openvpn/ta.key
    echo ${client_crt} | base64 -d > /etc/openvpn/client.crt
    echo ${client_key} | base64 -d > /etc/openvpn/client.key

    cat <<EOF > /etc/openvpn/client.conf
client
dev tun
proto ${proto}
remote ${host} ${port}
resolv-retry infinite
nobind
persist-key
persist-tun
ca ca.crt
cert client.crt
key client.key
tls-auth ta.key 1
ns-cert-type server
verb 3
cipher AES-256-CBC
auth SHA256
key-direction 1
EOF

    echo ""
    echo "Run openvpn"
      service openvpn start client > $log_path 2>&1
    echo "Done"
    echo ""

    echo "Check status"
    sleep 5
    if ! ifconfig | grep tun0 > /dev/null ; then
      echo "No open VPN tunnel found"
      cat "$log_path"
      exit 1
    fi
    echo "Done"
    ;;
  darwin*)
    echo "Configuring for Mac OS"

    echo ${ca_crt} | base64 -D -o ca.crt
    echo ${ta_key} | base64 -D -o ta.key
    echo ${client_crt} | base64 -D -o client.crt
    echo ${client_key} | base64 -D -o client.key
    echo ""

    echo "Run openvpn"
      sudo openvpn --client --dev tun --proto ${proto} --remote ${host} ${port} --resolv-retry infinite --nobind --persist-key --persist-tun --verb 3 --ca ca.crt --cert client.crt --key client.key --tls-auth ta.key 1 --key-direction 1 --auth SHA256 --cipher AES-256-CBC > $log_path 2>&1 &
    echo "Done"
    echo ""

    echo "Check status"
    sleep 5
    if ! ps -p $! >&-; then
      echo "Process exited"
      cat "$log_path"
      exit 1
    fi
    echo "Done"
    ;;
  *)
    echo "Unknown operative system: $OSTYPE, exiting"
    exit 1
    ;;
esac
