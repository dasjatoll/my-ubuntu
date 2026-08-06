#!/bin/bash
HOSTS=("nora" "omen" "uvier" "cube")
for h in "${HOSTS[@]}"; do
    ssh alex@$h "sudo apt update && sudo apt install -y cockpit netdata"
    ssh alex@$h "sudo systemctl enable --now cockpit.socket netdata"
done
# Ubuntu Pro: Token aus Umgebungsvariable oder interaktiv abfragen
read -sp "Ubuntu Pro Token: " TOKEN
for h in "${HOSTS[@]}"; do
    ssh alex@$h "sudo pro attach $TOKEN"
done