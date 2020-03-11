#!/bin/sh
#
# Coding Server Deployment Script using Backlog
# ----------
# Version 0.1
# By Katz Ueno

# INSTRUCTION:
# ----------
# https://github.com/katzueno/shell-conding-server-deployment

# USE IT AT YOUR OWN RISK!

# ----------
# COMMAND Options
# ----------
# sh setup_cooding.sh [SUBDOMAIN] [Backlog Proj Name] [GIT Name] [BRANCH] [BASIC AUTH USERNAME] [PASSWORD] [DEPLOY KEY]
# e.g.) sh setup_cooding.sh coding PROJ test master coding 123456 ABCDEFG123456

# $1 [SUBDOMAIN]
# $2 [Backlog Proj Name]
# $3 [GIT Name]
# $4 [BRANCH]
# $5 [BASIC AUTH USERNAME]
# $6 [PASSWORD]
# $7 [DEPLOY KEY]


echo "===================================="
echo "=        CODING SERVER SETUP       ="
echo "===================================="

# --------------------
# GET PARAMETERS
# --------------------
SUBDOMAIN=$1
BACKLOG_PROJECTNAME=$2
GIT_NAME=$3
BRANCH=$4
BASICAUTH_USERNAME=$5
BASICAUTH_PASSWORD=$6
DEPLOY_KEY=$7


# --------------------
# SET PARAMETERS
# --------------------

# Domains & Basic Auth
MAIN_DOMAIN="example.com"
MAIN_BASICAUTH="username:password"
CURRENT_DIR="/var/www/vhosts/shell"
DIR_OWNER="nginx:nginx"
WEB_USER="nginx"

# AWS Related Info
AWS_HOSTED_ZONE="ZXXXXXXXXXXXXXXX"
AWS_EIP="192.169.XXX.XXX"

# Backlog
BACKLOG_SPACE="c5japaninc"

# Wiki Deploy PHP Location
DEPLOY_URL="https://${BACKLOG_SPACE}.backlog.jp/git/XXXXXX/XXXXXXXXXXXXXX/blob/master/${SUBDOMAIN}.php"
GIT_WEB="https://${BACKLOG_SPACE}.backlog.jp/git/${BACKLOG_PROJECTNAME}/${GIT_NAME}/tree/${BRANCH}"
GIT_SSH="${BACKLOG_SPACE}@${BACKLOG_SPACE}.git.backlog.jp:/${BACKLOG_PROJECTNAME}/${GIT_NAME}.git"
DEPLOY_WEBHOOK="https://${MAIN_BASICAUTH}@${MAIN_DOMAIN}/${SUBDOMAIN}.php?key=${DEPLOY_KEY}"


# --------------------
# Function: Main Menu
# --------------------

show_main_menu()
{
  
  echo "-- Parameter Check --"
  echo "# Subdomain"
  echo "Subdomain:   ${SUBDOMAIN}.${MAIN_DOMAIN}"
  echo "# Backlog"
  echo "ProjectName: ${BACKLOG_PROJECTNAME}"
  echo "Git Name:    ${GIT_NAME}"
  echo "Git Branch:  ${BRANCH}"
  echo "Git SSH:     ${GIT_SSH}"
  echo "Git Web:     ${GIT_WEB}"
  echo "# Basic Auth"
  echo "Username:    ${BASICAUTH_USERNAME}"
  echo "Password:    ${BASICAUTH_PASSWORD}"
  echo "# PHP Deployment"
  echo "Deploy PHP:  ${DEPLOY_URL}"
  echo "Deploy Key:  ${DEPLOY_KEY}"
  echo " -- -- -- -- -- -- -- -- -- -- --"
  echo "[y]. Proceed?"
  echo "[q]. Quit?"
}


# --------------------
# Function: Process Main Menu
# --------------------

do_main_menu()
{
    show_main_menu
    read -p "Enter your selection:  (y/q): " yesno
    case "$yesno" in [yY]*) ;; *) echo "Sorry, see you soon!" ; exit ;; esac
    do_create
    do_route53
    show_wiki
    echo "---------------------------"
    echo "---      Complete!      ---"
    echo "---------------------------"
    exit 0
}


# --------------------
# Function: Create vhosts directory area, git clone, Nginx config change
# --------------------

do_create() {

    # STEP 1: Make a directory in vhosts    
    echo "**NOW** Making vhost directory"
    echo "/var/www/vhosts/${SUBDOMAIN}.${MAIN_DOMAIN}"
    cd /var/www/vhosts/
    mkdir /var/www/vhosts/${SUBDOMAIN}.${MAIN_DOMAIN}
    sudo chown -R ${DIR_OWNER} /var/www/vhosts/${SUBDOMAIN}.${MAIN_DOMAIN}
    sudo chmod -R 775 /var/www/vhosts/${SUBDOMAIN}.${MAIN_DOMAIN}
    
    # STEP 2: Clone git
    echo "**NOW** Cloning git"
    echo "sudo -u ${WEB_USER} git clone ${GIT_SSH} ./"
    cd /var/www/vhosts/${SUBDOMAIN}.${MAIN_DOMAIN}/
    sudo -u ${WEB_USER} git clone ${GIT_SSH} ./
    sudo -u ${WEB_USER} git checkout ${BRANCH}
    
    # STEP 3: Copy ${WEB_USER} config
    echo "**NOW** Copying ${WEB_USER} config"
    echo "/etc/nginx/conf.d/$(date "+%Y%m%d")_vhost_${SUBDOMAIN}.${MAIN_DOMAIN}.conf"
    cd /etc/httpd/conf.d/
    sudo cp /etc/nginx/conf.d/00000000_vhost_test.${MAIN_DOMAIN}.conf.template /etc/nginx/conf.d/$(date "+%Y%m%d")_vhost_${SUBDOMAIN}.${MAIN_DOMAIN}.conf
    
    # STEP 4: Setting up Nginx Config
    echo "**NOW** Setting up Nginx Config"
    sudo sed -i "s/SUBDOMAIN.${MAIN_DOMAIN}/${SUBDOMAIN}.${MAIN_DOMAIN}/g" /etc/nginx/conf.d/$(date "+%Y%m%d")_vhost_${SUBDOMAIN}.${MAIN_DOMAIN}.conf
    
    # STEP 5: Restarting Nginx
    echo "**NOW** Restarting Nginx"
    sudo nginx -t
    sudo systemctl restart nginx
    
    # STEP 6: Setting up Basic Auth
    echo "**NOW** Setting up Basic Auth"
    echo "Username: ${BASICAUTH_USERNAME}"
    echo "Password: ${BASICAUTH_PASSWORD}"
    sudo echo "${BASICAUTH_USERNAME}:$(openssl passwd -apr1 ${BASICAUTH_PASSWORD})" >> /etc/nginx/conf.d/htpasswd
    
    # STEP 7: Copying auto deploy php from template
    echo "**NOW** Copying deployment php file from template"
    echo "/var/www/vhosts/${MAIN_DOMAIN}/${SUBDOMAIN}.php"
    sudo -u ${WEB_USER} cp /var/www/vhosts/${MAIN_DOMAIN}/base.php.sample /var/www/vhosts/${MAIN_DOMAIN}/${SUBDOMAIN}.php
    
    # STEP 8: Setting up auto deploy php
    echo "**NOW** Setting up auto-deploy php"
    sudo sed -i "s/ENTERPASS/${DEPLOY_KEY}/g" /var/www/vhosts/${MAIN_DOMAIN}/${SUBDOMAIN}.php
    sudo sed -i "s/SUBDOMAIN/${SUBDOMAIN}/g" /var/www/vhosts/${MAIN_DOMAIN}/${SUBDOMAIN}.php
    echo "Webhook URL:"
    echo "${DEPLOY_WEBHOOK}"

    # STEP 9: Committing the git deploy changes to Backlog
    cd /var/www/vhosts/${MAIN_DOMAIN}/
    sudo -u ${WEB_USER} git add .
    sudo -u ${WEB_USER} git commit -m "${SUBDOMAIN}.${MAIN_DOMAIN} added"
    sudo -u ${WEB_USER} git push
}


# --------------------
# Function: Register subdomain to DNS zone via Route 53
# --------------------
do_route53() {
ROUTE53_JSON=$(cat << EOS
{
    "Comment": "CREATE/DELETE/UPSERT a record ",
    "Changes": [{
        "Action": "CREATE",
        "ResourceRecordSet": {
            "Name": "${SUBDOMAIN}.${MAIN_DOMAIN}",
            "Type": "A",
            "TTL": 300,
            "ResourceRecords": [{ "Value": "${AWS_EIP}"}]
    }}]
}
EOS
)
cd ${CURRENT_DIR}
echo ${ROUTE53_JSON} > route53.json
aws route53 change-resource-record-sets --hosted-zone-id ${AWS_HOSTED_ZONE} --change-batch file://route53.json
}


# --------------------
# Function: Create Markdown for Wiki
# --------------------
show_wiki() {
cat << EOS
==============================
Wiki Document Server/Coding
==============================
[toc]

# Basic 認証

| ID | Password
|:- | :- |
| ${BASICAUTH_USERNAME} | ${BASICAUTH_PASSWORD} |

https://${SUBDOMAIN}.${MAIN_DOMAIN}/

# Git 連携

----|------
連携 Git | ${GIT_WEB}
連携 Branch | ${GIT_NAME}
reset hard | あり
自動デプロイスクリプト| ${DEPLOY_URL}

* deploy script does not change branch, you must git checkout on the server directly
* サーバー上でブランチを変更したい場合は git checkout コマンドを直接サーバー上で実行すること

# サーバー情報

## インストールパス

/var/www/vhosts/${SUBDOMAIN}.${MAIN_DOMAIN}

==============================
EOS

echo "# Webhook URL:"
echo "${DEPLOY_WEBHOOK}"

}

# --------------------
# Bootstrap
# --------------------
do_main_menu
