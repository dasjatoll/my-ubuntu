#!/bin/bash
HOSTS=
# /etc/hosts Einträge (nur wenn nicht vorhanden)
for h in "${HOSTS[@]}"; do
    ssh root@$h "grep -q '10.10.10.12 nora' /etc/hosts || echo '10.10.10.12 nora' >> /etc/hosts"
    ssh root@$h "grep -q '10.10.10.24 omen' /etc/hosts || echo '10.10.10.24 omen' >> /etc/hosts"
ssh root@$h "grep -q '10.10.10.36 uvier' /etc/hosts || echo '10.10.10.36 uvier' >> /etc/hosts"
ssh root@$h "grep -q '10.10.10.48 cube' /etc/hosts || echo '10.10.10.48 cube' >> /etc/hosts"
done

# sshd_config: AllowUsers setzen
for h in "${HOSTS[@]}"; do
    ssh root@$h "sed -i '/^AllowUsers/d' /etc/ssh/sshd_config"
    ssh root@$h "echo 'AllowUsers alex@10.10.10.12 alex@10.10.10.24 alex@10.10.10.36 alex@10.10.10.48' >> /etc/ssh/sshd_config"
    ssh root@$h "systemctl reload sshd"
done


