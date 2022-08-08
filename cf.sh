#!/bin/bash
CFEMAIL=''
CFAPI=''
CFZONEID=''

DB_USER=''
DB_PASSWD=''
DB_NAME=''
DB_HOST=''

STORAGE_HOST=''
STORAGE_USER=''

MX=''
A=''
SPF=''
CNAME=''

TODAY=$(date +"%Y%m%d")

generate_post_data()
{
  cat <<EOF
{
  "type":"TXT",
  "name":"${domain}",
  "content":"${SPF}",
  "ttl":300,
  "proxied":false
}
EOF
}


check_domain () {
    domain="$1"

    if [ -z "$domain" ]; then
        echo  'Please provide a domain.'
        exit
    fi

    if [ "$(echo $domain | grep -P '(?=^.{1,254}$)(^(?>(?!\d+\.)[a-zA-Z0-9_\-]{1,63}\.?)+(?:[a-zA-Z]{2,})$)')" = "$domain" ]; then
        echo $domain ' is a valid domain.'
    else
        echo 'Please provide a valid domain.'
        exit
    fi
}

get_zoneid () {

    domain="$1"

    echo 'Get the id assigned to: ' $domain
    QDDOMAINID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${domain}" \
        -H "X-Auth-Email: ${CFEMAIL}" \
        -H "X-Auth-Key: ${CFAPI}" \
        -H "Content-Type: application/json" \
    | jq -r '.result | .[0] | .id' )

    if [ -z "${QDDOMAINID}" ]; then
        echo 'Something wrong with your input ' $domain ' according with cloudflare its id is ' $QDDOMAINID
        exit
    else
        echo $domain ' has the id: ' $QDDOMAINID
    fi
}


while [[ $# -gt 0 ]]; do
    key="$1"
    domain="$2"
    flag="$3"

    if [ -z "$key" ]; then
        echo 'Please provide an argument followed by a domain name.'
        exit
    fi

    case $key in
        create)
            echo 'Create We are working for: ' $domain
            check_domain $domain

            curl -X POST "https://api.cloudflare.com/client/v4/zones" \
                -H "X-Auth-Email: ${CFEMAIL}" \
                -H "X-Auth-Key: ${CFAPI}" \
                -H "Content-Type: application/json" \
                --data '{"name":"'$domain'","account":{"id":"'${CFZONEID}'"},"jump_start":false,"type":"full"}' \
                | jq -r 

            sleep 5
            get_zoneid $domain

            curl -X PATCH "https://api.cloudflare.com/client/v4/zones/${QDDOMAINID}/settings/ssl" \
                -H "X-Auth-Email: ${CFEMAIL}" \
                -H "X-Auth-Key: ${CFAPI}" \
                -H "Content-Type: application/json" \
                --data '{"value":"strict"}' \
                | jq -r 

            exit 0
        ;;
        add)
            echo 'Add We are working for: ' $domain
            check_domain $domain

            case $flag in
              mx)
                get_zoneid $domain

        curl -X POST "https://api.cloudflare.com/client/v4/zones/${QDDOMAINID}/dns_records" \
                -H "X-Auth-Email: ${CFEMAIL}" \
                -H "X-Auth-Key: ${CFAPI}" \
                -H "Content-Type: application/json" \
                --data '{"type":"MX","name":"'$domain'","content":"'$MX1'","ttl":300,"priority":0,"proxied":false}'

        curl -X POST "https://api.cloudflare.com/client/v4/zones/${QDDOMAINID}/dns_records" \
                -H "X-Auth-Email: ${CFEMAIL}" \
               -H "X-Auth-Key: ${CFAPI}" \
                -H "Content-Type: application/json" \
               --data '{"type":"MX","name":"'$domain'","content":"'$MX2'","ttl":300,"priority":0,"proxied":false}'
         exit 0
        ;;
        spf)
 get_zoneid $domain
        curl -X POST "https://api.cloudflare.com/client/v4/zones/${QDDOMAINID}/dns_records" \
                -H "X-Auth-Email: ${CFEMAIL}" \
                -H "X-Auth-Key: ${CFAPI}" \
                -H "Content-Type: application/json" \
                --data "$(generate_post_data)"
        exit 0
        ;;
        a)
 get_zoneid $domain
        curl -X POST "https://api.cloudflare.com/client/v4/zones/${QDDOMAINID}/dns_records" \
                -H "X-Auth-Email: ${CFEMAIL}" \
                -H "X-Auth-Key: ${CFAPI}" \
                -H "Content-Type: application/json" \
                --data '{"type":"A","name":"'$domain'","content":"'$A1'","ttl":300,"proxied":true}'
        curl -X POST "https://api.cloudflare.com/client/v4/zones/${QDDOMAINID}/dns_records" \
                -H "X-Auth-Email: ${CFEMAIL}" \
                -H "X-Auth-Key: ${CFAPI}" \
                -H "Content-Type: application/json" \
                --data '{"type":"A","name":"www.'$domain'","content":"'$A1'","ttl":300,"proxied":true}'
        exit 0
        ;;

        *)
            echo 'Please provide the kind of add.'
            exit 0
        ;;

        esac
            exit 0
        ;;
        delete)
            check_domain $domain
            get_zoneid $domain

            curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${QDDOMAINID}/dns_records/export" \
                -H "X-Auth-Email: ${CFEMAIL}" \
                -H "X-Auth-Key: ${CFAPI}" \
                -H "Content-Type: application/json" \
                -o ${domain}_zone_${TODAY}.bin

            scp ${domain}_zone_${TODAY}.bin ${STORAGE_USER}@${STORAGE_HOST}:/
            
            if [ $? -eq 0 ]; then
                echo 'File Transferred'

                curl -X DELETE "https://api.cloudflare.com/client/v4/zones/${QDDOMAINID}" \
                -H "X-Auth-Email: ${CFEMAIL}" \
                -H "X-Auth-Key: ${CFAPI}" \
                -H "Content-Type: application/json" \
                | jq -r '.success '

                echo 'Domain deleted.'

            else
                echo 'FAIL'
            fi

            exit 0
        ;;
        list)
            check_domain $domain
            get_zoneid $domain

            curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${QDDOMAINID}/dns_records/export" \
                -H "X-Auth-Email: ${CFEMAIL}" \
                -H "X-Auth-Key: ${CFAPI}" \
                -H "Content-Type: application/json" \
                -o ${domain}_zone_${TODAY}.bin

            scp ${domain}_zone_${TODAY}.bin ${STORAGE_USER}@${STORAGE_HOST}:/

            if [ $? -eq 0 ]; then
                echo 'File Transferred'
            else
                echo 'FAIL'
            fi

            exit 0
        ;;
        info)
            check_domain $domain
            QDDOMAINSTATUS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${2}" \
                -H "X-Auth-Email: ${CFEMAIL}" \
                -H "X-Auth-Key: ${CFAPI}" \
                -H "Content-Type: application/json" \
            | jq -r '.result | .[0] | .status' )

            if [ -z "${QDDOMAINSTATUS}" ]; then
                echo 'Something wrong with your input ' $domain ' according with cloudflare it is ' $QDDOMAINSTATUS
            elif [ "${QDDOMAINSTATUS}" = "active" ]; then
                echo $domain ' is already on cloudflare, and ' $QDDOMAINSTATUS
            elif [ "${QDDOMAINSTATUS}" = "moved" ]; then
                echo $domain ' is no longer on cloudflare, and ' $QDDOMAINSTATUS                
            else
                echo $domain ' does not exists on cloudflare.'
            fi
            exit 0
        ;;
        search)
            QDPAGECOUNT=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?per_page=50" \
                -H "X-Auth-Email: ${CFEMAIL}" \
                -H "X-Auth-Key: ${CFAPI}" \
                -H "Content-Type: application/json" \
            | jq -r '.result_info | .total_pages ' )

                for (( c=1; c<=$QDPAGECOUNT; c++ ))
                do
                        declare RESULT=($(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?per_page=50&page=$c" \
                                -H "X-Auth-Email: ${CFEMAIL}" \
                                -H "X-Auth-Key: ${CFAPI}" \
                                -H "Content-Type: application/json"\
                        | jq -r '.result | .[] | .name '))

                        for domain in "${RESULT[@]}"
                        do

    QDDOMAINID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${domain}" \
        -H "X-Auth-Email: ${CFEMAIL}" \
        -H "X-Auth-Key: ${CFAPI}" \
        -H "Content-Type: application/json" \
    | jq -r '.result | .[0] | .id' )

        curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${QDDOMAINID}/dns_records?type=A&content=164.132.75.19" \
        -H "X-Auth-Email: ${CFEMAIL}" \
        -H "X-Auth-Key: ${CFAPI}" \
        -H "Content-Type: application/json" \
    | jq -r '.result | .[0] | .name, .content'


                        done
                done


        exit 0
        ;;
        *)
            echo 'Please provide the argument: create, add, edit, list or info.'
            exit 0
        ;;
    esac
done


#### DEBUG ######
# echo "curl -s -X GET https://api.cloudflare.com/client/v4/zones?name=${2} -H \"X-Auth-Email: ${CFEMAIL}\" -H \"X-Auth-Key: ${CFAPI}\" -H \"Content-Type: application/json\" | jq -r"


