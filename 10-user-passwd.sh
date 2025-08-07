#!/bin/sh

kubectl patch svc example1-rw -p '{"spec":{"type":"NodePort"}}'

# Port forward PostgreSQL to localhost:15432
kubectl port-forward svc/example1-rw 15432:5432 &
PORT_FORWARD_PID=$!

user=`kubectl get secret example1-app -o jsonpath="{.data.username}" | base64 --decode`
passwd=`kubectl get secret example1-app -o jsonpath="{.data.password}" | base64 --decode && echo`

echo "username: $user"
echo "password: $passwd"
echo "psql -h 127.0.0.1 -p 5432 -U $user -d app -W"
echo ""
echo "Port forward PID: $PORT_FORWARD_PID"
echo "To stop port forward: kill $PORT_FORWARD_PID"
