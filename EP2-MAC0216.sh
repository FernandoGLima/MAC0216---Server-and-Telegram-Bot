#!/bin/bash

echo -n "Digite o intervalo de tempo (em segundos) em que o programa verficará o sistema:"     #printa na tela do usuario essas frases e
read TEMPO_VERIFICA                                                                            #armazena cada valor digitado do usario
echo -n "Digite o arquivo de saida:"                                                           #na variavel respectiva
read ARQUIVO_SAIDA
echo -n "Digite o Limite(em porcentagem) da CPU:"
read LIMITE_CPU
echo -n "Digite o TOKEN do bot:"
read TOKEN_BOT
echo -n "Digite o ID do bot:"
read ID_BOT

CONTADOR=0
MEDIA=0                                               #inicia variaveis que serão uteis ao longo do programa
TEMPO_OFFLINE=0

if [ -e "$ARQUIVO_SAIDA" ]; then                      #se existir o arquivo digitado pelo usuario as saidas serao enviadas para ele, sem apagar o que ja estiver nele. 
    echo "EP2" >> $ARQUIVO_SAIDA
else 
    touch $ARQUIVO_SAIDA                              #se nao existir entao cria este arquivo
    echo "EP2" >> $ARQUIVO_SAIDA                      
fi

while [ 1 ]; do                                        #while [1] é para que o programa rode infinitamente ate o usuario fechar seu terminal ou da ctrl+c

    let CONTADOR=CONTADOR+1                            #incrementa o contador, este sera util pra saber quantas medições foram feitas.
    echo -e  $"\n"
    echo -e $"\n" >> $ARQUIVO_SAIDA                    #printa na tela e escreve no arquivo um pula linha (por um melhor padrão estético)

    DATA=$( date +"%D ")
    HORARIO=$( date +"%T ")                            #adiciona na variavel data a data atual e na variavel horario o horario atual
    
    CPU=$( mpstat | grep "all" | cut -d ' ' -f 45 )     #utiliza o comando mpstat para pegar a ociosidade da cpu e dar para esta variavel. O comando grep all seleciona a linha em que tal numero aparece e o cut corta esse numero

    SERVIDOR=$( netstat -anp 2>/dev/null | grep 45052 | grep "LISTEN" | cut -d ' ' -f 42 )  #utiliza o comando netstat junto com o grep 45052 para ver a lista se o servidor ta online, o grep listen junto com o cut atribuem "LISTEN" para a variavel servidor

    IPS=$( netstat -anp 2>/dev/null | grep 45052 | grep "ESTABLISHED" | cut -d ' ' -f 16 | grep -v "127.0.0.1:45052" ) #este comando atribui a variavel ips os ips que estao conectados ao servidor. O grep "ESTABLISHED" é para pegar os ips conectados, enquanto o -v é para retirar o ip que acredito ser do servidor.
    VERIFICA_IPS=$( netstat -anp 2>/dev/null | grep 45052 | grep -c "ESTABLISHED" | cut -d ' ' -f 34 ) #este comando atribui a variavel verifica_ips se tem algum ip conectado
    
    MEDIA=$( echo "$CPU+$MEDIA" | bc )              #soma as ociosidades da cpu na media


    echo "Data de hoje:" $DATA
    curl -s --data "text=Data de hoje:$DATA                   Horario Atual:$HORARIO"  https://api.telegram.org/bot$TOKEN_BOT/sendMessage?chat_id=$ID_BOT 1>/dev/null
    echo "Horario Atual:" $HORARIO
    echo "Data de hoje:" $DATA >> $ARQUIVO_SAIDA
    echo "Horario Atual:" $HORARIO >> $ARQUIVO_SAIDA                #printa na tela, escreve no arquivo e envia a mensagem pelo telegram o horario e a data


    if [ "$SERVIDOR" != "LISTEN" ]; then                    #verifica se o servidor esta online, se nao estiver printa, escreve no arquivo e envia pelo telegram que o servidor esta offline
        echo "O Servidor esta offline"
        curl -s --data "text=O servidor esta offline"  https://api.telegram.org/bot$TOKEN_BOT/sendMessage?chat_id=$ID_BOT 1>/dev/null
        echo "O Servidor esta offline" >> $ARQUIVO_SAIDA
        let TEMPO_OFFLINE=TEMPO_OFFLINE+$TEMPO_VERIFICA        #adiciona o tempo que o servidor esta offline (o tempo que demorara até a proxima verificação será o tempo que o server esta offline)
    elif [ $(echo "$VERIFICA_IPS>0" | bc ) -eq 1 ]; then
        echo "O(s) IP(s) conectado(s):" "$IPS"
        curl -s --data "text=O(s) IP(s) conectado(s):$IPS" https://api.telegram.org/bot$TOKEN_BOT/sendMessage?chat_id=$ID_BOT 1>/dev/null
        echo "O(s) IP(s) conectado(s):" "$IPS" >> $ARQUIVO_SAIDA                    #se o sever estiver online, verifica se tem ips conectados se tiver printa, escreve no arquivo e manda pelo telegram os ips conectados
    fi


    echo "A CPU esta (em porcentagem) ociosa: $CPU" >> $ARQUIVO_SAIDA               #escreve no arquivo a ociosidade da cpu
    if [ $(echo "$LIMITE_CPU>$CPU" | bc ) -eq 1 ]; then                          #verifica se a ociosidade da cpu esta menor que o limite passado, se estiver, printa e manda pelo telegram a ociosidade
        echo "A CPU esta (em porcentagem) ociosa: $CPU , abaixo do limite passado"
        curl -s --data "text=A CPU esta (em porcentagem) ociosa:$CPU , abaixo do limite passado"  https://api.telegram.org/bot$TOKEN_BOT/sendMessage?chat_id=$ID_BOT 1>/dev/null
    fi


    if [ $CONTADOR -eq 100 ]; then                                                  #quando o contador chegar em 100, calcula a media das ultimas 100 ociosidades da cpu e escreve no arquivo
        MEDIA=$( echo "$MEDIA/$CONTADOR" | bc -l )                                     # e tambem escreve no arquivo por quanto tempo o server ficou offline durante as ultimas 100 verificações
        echo "A media de ociosidade da CPU, das 100 ultimas verificações:" $MEDIA >> $ARQUIVO_SAIDA
        echo "A quantidade de tempo (em segundos) que o servidor ficou offline nas ultimas 100 verificações:" $TEMPO_OFFLINE >> $ARQUIVO_SAIDA
        
        let CONTADOR=0
        let MEDIA=0                                                                 #zera o contador, a media e o tempo offline para que se possa registrar novamente para as proximas 100 verificações
        let TEMPO_OFFLINE=0
    fi

    sleep $TEMPO_VERIFICA                                                           #o programa espera o intervalo passado pelo usuario até a proxima verificação

done

exit 0
