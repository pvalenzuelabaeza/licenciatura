#---------------------------------------------------------------------------------------
# Monitoring script (per server)
# Version : 1.0
# creation date : September 11, 2023
# created by    : Patricio Valenzuela - Cloud Infrastructure Architect
#
# CHANGE : Work path
#
# Version Update date  Updated by        Reason for update
# ------- -----------  ----------        -----------------
#
#---------------------------------------------------------------------------------------
#!/bin/bash

#----------------------------------------------------------------------------------------------
# Environment Variables
#----------------------------------------------------------------------------------------------
ldate=$(date)
lid=$(whoami)

export PPATH=/home/opc/ansible
export ansible_cfg=$PPATH/'ansible.cfg'
export db_information=$PPATH/'db_information.sql'
export db_report=$PPATH/'db_report.txt'

#----------------------------------------------------------------------------------------------
# Functions Database
#----------------------------------------------------------------------------------------------
function cfg_ansible () {
   echo '[defaults]'                                       >  $ansible_cfg
   echo 'host_key_checking = false'                        >> $ansible_cfg
   echo 'remote_user = opc'                                >> $ansible_cfg
   echo 'private_key_file = /home/opc/.ssh/id_rsa_bastion' >> $ansible_cfg
}

function db_info () {
   echo 'use monsys'                                       >  $db_information
   echo 'select * from monsys.Servidor ;'                  >> $db_information
   mysql -u root -pmonsys  monsys < $db_information        >  $db_report
   rm -Rf $db_information
}

function db_exe_playbook () {
  lserver=`cat ${db_report} | grep -v Kernel | awk '{print $3}'`
  for fs in ${lserver}
  do
    name=${fs}'_inventario'
    nam1=${fs}'_disco.yaml'
    nam2=${fs}'_memoria.yaml'

    dis1=${fs}'_disco.txt'
    dis2=${fs}'_disco_filter.txt'
    disS=${fs}'_actualiza.sql'

    mem1=${fs}'_memoria.txt'
    mem2=${fs}'_memoria_filter.txt'
    memS=${fs}'_actualiza_mem.sql'


    line=${fs}" ansible_host="`cat ${db_report} | grep -i ${fs} | awk '{print $2}'`
    ipdd=`cat ${db_report} | grep -i ${fs} | awk '{print $2}'`
    echo $line                                                           >  $PPATH/$name

    echo '---'                                                           >  $PPATH/$nam1
    echo '- name: Valida Espacio en Disco'                               >> $PPATH/$nam1
    echo '  hosts: all'                                                  >> $PPATH/$nam1
    echo ' '                                                             >> $PPATH/$nam1
    echo '  tasks:'                                                      >> $PPATH/$nam1
    echo '  - name: Valida Espacio'                                      >> $PPATH/$nam1
    echo '    ansible.builtin.shell: df -m'                              >> $PPATH/$nam1
    echo '    register: espacio_disco'                                   >> $PPATH/$nam1
    echo '  '                                                            >> $PPATH/$nam1
    echo '  - name: Imprime Espacio en Disco'                            >> $PPATH/$nam1
    echo '    ansible.builtin.debug:'                                    >> $PPATH/$nam1
    echo '      msg: "{{ espacio_disco.stdout_lines }}"'                 >> $PPATH/$nam1
    echo ' '                                                             >> $PPATH/$nam1

    echo '---'                                                           >  $PPATH/$nam2
    echo '- name: Valida Facts de Servidor'                              >> $PPATH/$nam2
    echo '  hosts: all'                                                  >> $PPATH/$nam2
    echo ''                                                              >> $PPATH/$nam2
    echo '  tasks:'                                                      >> $PPATH/$nam2
    echo '  - name: Memoria y Swap'                                      >> $PPATH/$nam2
    echo '    ansible.builtin.shell: free -m'                            >> $PPATH/$nam2
    echo '    register: salida_mem'                                      >> $PPATH/$nam2
    echo ''                                                              >> $PPATH/$nam2
    echo '  - name: Imprime memoria disponible'                          >> $PPATH/$nam2
    echo '    ansible.builtin.debug:'                                    >> $PPATH/$nam2
    echo '      msg: "{{ salida_mem.stdout_lines }}"'                    >> $PPATH/$nam2
    echo '  '                                                            >> $PPATH/$nam2

#   Ejecucion del Playbook de Disco
    ansible-playbook -i $PPATH/$name $PPATH/$nam1                        >  $PPATH/$dis1

    srvok=`cat $PPATH/$dis1 | grep -i unreachable=1 | wc -l`
    echo 'use monsys'                                                    >  $PPATH/$disS
    echo "delete from monsys.Espacio where ip='"${ipdd}"';"              >> $PPATH/$disS


    if  test ${srvok} -eq 0 ;then
        warning=`cat ${db_report} | grep -i ${fs} | awk '{print $4}'`
        critico=`cat ${db_report} | grep -i ${fs} | awk '{print $5}'`

        cat $PPATH/$dis1 |sed '/^ *$/d'|grep -v PLAY|grep -v TASK|grep -v Servidor1|grep -v msg|grep -v Filesystem|grep -v "]"|grep -v unreachable |grep -v "}" > $PPATH/$dis2
        while IFS= read -r line
        do
          fsys=`echo ${line} | awk '{print $6}' | cut -f 1 -d "," |  sed -e 's/"/\n/g'`
          asig=`echo ${line} | awk '{print $2}'`
          util=`echo ${line} | awk '{print $3}'`
          avai=`echo ${line} | awk '{print $4}'`
          porc=`echo ${line} | awk '{print $5}' | cut -f 1 -d "%"`
          if test ${porc} -ge ${critico};then
             Est="C"
             Com='FileSystem al : '${porc}'% - Liberar Espacio'
          elif test ${porc} -lt ${warning};then
             Est="O"
             Com='.'
          else
             Est="W"
             Com='FileSystem al : '${porc}'% - Liberar Espacio'
          fi

          line0="insert into Espacio values (1,'"${ipdd}"',date(now()),'"${fsys}"',"${asig}","${util}","${avai}","${porc}",'"${Est}"','"${Com}"');"
          echo ${line0}                                                  >> $PPATH/$disS
        done < $PPATH/$dis2
    else
        line0="insert into Espacio values (1,'"${ipdd}"',date(now()),'Espacio FS',0,0,0,0,'C','Servidor APAGADO o fuera de Red');"
        echo ${line0}                                                    >> $PPATH/$disS
    fi
    mysql -u root -pmonsys  monsys < $PPATH/$disS
    rm -Rf $PPATH/$dis1 $PPATH/$dis2 $PPATH/$disS

#   Ejecucion del Playbook de Memoria
    ansible-playbook -i $PPATH/$name $PPATH/$nam2                        >  $PPATH/$mem1

    srvok=`cat $PPATH/$mem1 | grep -i unreachable=1 | wc -l`
    echo 'use monsys'                                                    >  $PPATH/$disS
    echo "delete from Memoria where ip='"${ipdd}"';"                     >> $PPATH/$disS

    if  test ${srvok} -eq 0 ;then
        asig=`cat $PPATH/$mem1 | grep -v TASK | grep -i Mem | awk '{print $2}'`
        util=`cat $PPATH/$mem1 | grep -v TASK | grep -i Mem | awk '{print $3}'`
        avai=`cat $PPATH/$mem1 | grep -v TASK | grep -i Mem | awk '{print $4}'`
        por1=`expr ${util} \* 100`
        por2=`expr ${por1} / ${asig} `
        porc=${por2%.*}
        Est="O"
        Com='.'
        line0="insert into Memoria values (1,'"${ipdd}"',date(now()),'Mem',"${asig}","${util}","${avai}","${porc}",'"${Est}"','"${Com}"');"
        echo ${line0}                                                    >> $PPATH/$disS

        asig=`cat $PPATH/$mem1 | grep -v TASK | grep -i Swap | awk '{print $2}'`
        util=`cat $PPATH/$mem1 | grep -v TASK | grep -i Swap | awk '{print $3}'`
        avai=`cat $PPATH/$mem1 | grep -v TASK | grep -i Swap | awk '{print $4}' | cut -f 1 -d '"'`
        por1=`expr ${util} \* 100`
        por2=`expr ${por1} / ${asig} `
        porc=${por2%.*}
        Est="O"
        Com='.'
        line0="insert into Memoria values (1,'"${ipdd}"',date(now()),'Swap',"${asig}","${util}","${avai}","${porc}",'"${Est}"','"${Com}"');"
        echo ${line0}                                                    >> $PPATH/$disS
    else
        line0="insert into Memoria values (1,'"${ipdd}"',date(now()),'Mem',0,0,0,0,'C','Servidor APAGADO o fuera de Red');"
        echo ${line0}                                                    >> $PPATH/$disS
        line0="insert into Memoria values (1,'"${ipdd}"',date(now()),'Swap',0,0,0,0,'C','Servidor APAGADO o fuera de Red');"
        echo ${line0}                                                    >> $PPATH/$disS
    fi

    mysql -u root -pmonsys  monsys < $PPATH/$disS
    rm -Rf $PPATH/$mem1 $PPATH/$disS $PPATH/$nam1 $PPATH/$nam2 $PPATH/$name

  done
  rm -Rf $db_report
}


if [ ! -f $ansible_cfg ];
then
   cfg_ansible
fi
db_info
db_exe_playbook
