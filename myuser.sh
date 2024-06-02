#!/bin/bash

CONNECTION_CMD=
# Função para exibir a ajuda
usage() {
    echo "Uso: $0 --user=USUARIO --password=SENHA --host=IP --port=PORTA --result=ARQUIVO_RESULTADO [--target=VERSAO] [--socket=SOCKET]"
    exit 1
}

# Função para processar os parâmetros
process_params() {
    for i in "$@"
    do
    case $i in
        --user=*)
        MUSER="${i#*=}"
        shift
        ;;
        --password=*)
        PASSWORD="${i#*=}"
        shift
        ;;
        --host=*)
        HOST="${i#*=}"
        shift
        ;;
        --port=*)
        PORT="${i#*=}"
        shift
        ;;
        --result=*)
        RESULT="${i#*=}"
        shift
        ;;
        --target=*)
        TARGET="${i#*=}"
        shift
        ;;
        --socket=*)
        SOCKET="${i#*=}"
        shift
        ;;
        *)
        usage
        ;;
    esac
    done
}

# Função para verificar os parâmetros obrigatórios
check_mandatory_params() {
    if [ -z "$MUSER" ]; then
        echo
        read -p "Digite o usuário: " MUSER
    fi	
    
    if [ -z "$PASSWORD" ]; then
        echo
        read -sp "Digite a senha: " PASSWORD
        echo
    fi
    if [ -z "$HOST" ]; then
        echo
        read -p "Digite o host: " HOST
    fi
    if [ -z "$PORT" ]; then
        echo
        read -p "Digite a porta: " PORT
    fi
    if [ -z "$RESULT" ]; then
        echo
        read -p "Digite o arquivo de resultado: " RESULT
    fi
}

# Função para verificar os parâmetros opcionais
check_optional_params() {
    if [ -z "$TARGET" ]; then
        echo
        read -p "Digite o target (opcional): " TARGET
    fi
    if [ -z "$SOCKET" ]; then
        echo
        read -p "Digite o socket (opcional): " SOCKET
    fi
}

# Função para exibir os parâmetros recebidos
display_params() {
    echo "Usuário: $MUSER"
    echo "Senha: $PASSWORD"
    echo "Host: $HOST"
    echo "Porta: $PORT"
    echo "Resultado: $RESULT"

    if [ ! -z "$TARGET" ]; then
        echo "Target: $TARGET"
    fi

    if [ ! -z "$SOCKET" ]; then
        echo "Socket: $SOCKET"
    fi
}

# Função para tentar a conexão ao banco de dados
test_db_connection() {
    CONNECTION_CMD="mysql --user=$MUSER --password=$PASSWORD --host=$HOST --port=$PORT"
    if [ ! -z "$SOCKET" ]; then
        CONNECTION_CMD="mysql --user=$MUSER --password=$PASSWORD --socket=$SOCKET"
    fi

    echo "Tentando conectar ao banco de dados..."
    if ! eval "$CONNECTION_CMD -e 'SHOW DATABASES;' > /dev/null 2>&1"; then
        echo "Erro ao conectar ao banco de dados:"
        eval "$CONNECTION_CMD -e 'SHOW DATABASES;' 2>&1 | grep 'ERROR'"
        exit 1
    else
        echo "Conexão ao banco de dados bem-sucedida."
    fi
}

# Função para verificar a versão do MySQL e tomar ações específicas
check_mysql_version() {
    VERSION=$($CONNECTION_CMD -Bse "SELECT LEFT(VERSION(),3);" 2> /dev/null )
	current_date=$(date +"%Y-%m-%d %H:%M:%S")
	echo "### Autor : marcio28costa@hotmail.com | exportacao de usuarios no mysql | linux ###" > $RESULT
	echo "### host: $HOST - porta: $PORT - versao: $VERSION | $current_date ###" >> $RESULT
	echo "" >> $RESULT
	echo ""
    echo "Versão do MySQL: $VERSION"
    if [[ "$VERSION" == 5.6 ]] || [[ "$VERSION" == 4.1 ]]; then
        #echo "Ação específica para MySQL 4.x ou 5.6"
	usuarios=$($CONNECTION_CMD -Bse "select concat('\'',user,'\'@\'',host,'\'') from mysql.user where user not like 'mysql%' " 2> /dev/null )
        # Converte o resultado em um array
        IFS=$'\n' read -rd '' -a user_host_array <<< "$usuarios"

	echo "Iniciando exportacao ..."
        # Imprime os elementos do array
        for entry in "${user_host_array[@]}"; do
             echo "-- $entry -- ;" >> $RESULT
             COM2=$($CONNECTION_CMD -Bse "show grants for $entry "  2> /dev/null | awk '{print $0 ";"}' >> $RESULT)
             $COM2
        done
	echo "Exportacao Finalizada !!"

    elif [[ "$VERSION" == 5.7 ]] || [[ "$VERSION" == 8.0 ]]; then
		usuarios=$($CONNECTION_CMD -Bse "select concat('\'',user,'\'@\'',host,'\'') from mysql.user where user not like 'mysql%' " 2> /dev/null)
		
		# Converte o resultado em um array
		IFS=$'\n' read -rd '' -a user_host_array <<< "$usuarios"

		echo "Iniciando exportacao ..."
		# Imprime os elementos do array
		for entry in "${user_host_array[@]}"; do
			echo "-- $entry -- ;" >> $RESULT
			COM1=$($CONNECTION_CMD -Bse "show create user $entry "  2> /dev/null | awk '{print $0 ";"}' >> $RESULT )
			COM2=$($CONNECTION_CMD -Bse "show grants for $entry "  2> /dev/null | awk '{print $0 ";"}' >> $RESULT)
			$COM1
			$COM2
		done
		echo "Exportacao Finalizada !!"
	
    else
        echo "Versão do MySQL não tratada especificamente."
    fi

    echo "-- Exportacao Finalizada !! --"  >> $RESULT
}

# Função principal
main() {
    if [ "$#" -eq 0 ]; then
        echo "Nenhum parâmetro passado. Solicitando interativamente..."
    fi

    process_params "$@"
    check_mandatory_params
    check_optional_params
    #display_params
    test_db_connection
    check_mysql_version

    # Aqui você pode adicionar os comandos que quiser usar com os parâmetros recebidos
    # Por exemplo, uma conexão com o MySQL poderia ser feita assim:
    # mysql --user="$MUSER" --password="$PASSWORD" --host="$HOST" --port="$PORT" --socket="$SOCKET" -e "SHOW DATABASES;"

    # Salvando algum resultado no arquivo especificado
    # echo "Algum resultado" > "$RESULT"
}

# Chama a função principal
main "$@"

