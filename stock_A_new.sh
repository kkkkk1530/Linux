#!/bin/bash
#Author: Junjie.he
#Date: 2016-12-07
#Version 1.5
#export LC_ALL=en_US.UTF-8
#bash, version 3.2.25
####updatelog
#修复base64编码换行导致不能添加超过8个股票代码 update:2014-08-18
#修复输入股票代码不能正确的识别上交和深证的问题 update:2015-08-14
#添加颜色开关 update:2015-08-18
#输出显示优化（消除卡顿感） update:2016-08-20
#去掉临时文件，用变量代替数据存储，优化5档买卖显示 update:2016-12-07
#获取数据函数放后台，提升使用体验 update:2017-05-11
####


User_Add(){
        echo "$userName:$passwdMD5:" >> $userDataFile
}
User_Check(){
        if `grep -q -P "^$userName:" $userDataFile`;then
                if [ "$passwdMD5" != "$(awk -F: '/^'$userName':/{print $2}' $userDataFile)" ];then
                        echo -e "\nPassword error"
                        exit 1
                fi
        else
                User_Add
        fi
}
User_Data_Get(){
        userDataArray=(`awk -F: '/^'$userName':/{printf("%s",$3)}' $userDataFile|base64 -d|tr " " "\n"|sort|uniq|tr "\n" " "`)
}
User_Manage(){
        read -p "UserName : " userName
        read -s -p "Password : " userPasswd
        passwdMD5=`echo -n "${userPasswd}hejunjie"|md5sum|awk '{print $1}'`
        if [ -f $userDataFile ];then
                User_Check
        else
                User_Add
        fi
        User_Data_Get
}
Data_Update(){
        if [ "$dateStatus" != 0 ];then
                echo -n "Loading..."
        fi
        local stockCode=`echo $*|sed -r 's/\s/,/g'`
        dataFile="$(curl -s "${url}${stockCode}"|iconv -f gb2312 -t utf8|sed "/=\"\";/d")"
}
Color_Select(){
        echo "$*"|awk  '{if ($1==0) print "36";else if($1>$2) print "31";else if($1<$2) print "32";else print "37"}'
}
Data_Proces(){
F_tmp_1(){
        echo "$dataFile"|while read line
        do
                local color="$(Color_Select $(echo "$line"|awk -F[=\",_]+ '{print $7,$6}'))"
                local color1=30
                local color2=33
                local color3=34
                local g=1
                case $Color in 
                        on)local g1=2;;
                        ON)local g1=1;;
                        *)local color=37;local color1=37;local color2=37;local color3=37;local g=2;local g1=2;;
                esac
                echo $line|awk -F[=\",_]+ '/var.*'$1'=/{printf("\033[0;'$color3';'${g1}'m%8s\033[0m  \033[0;'$color';'${g1}'m%7.2f%%  %7.2f\033[0m   \033[0;'$color1';'${g}'m%7.2f\033[0m    \033[0;'$color2';'${g1}'m%-12s\033[0m\n",$3,($7-$6)/$6*100,$7-$6,$7,$4)}' 
        done
}
F_tmp_2(){
        echo "$dataFile"|awk -F[=\",_]+ '/var.*'$1'=/{print "开盘价:"$6,"卖五:"$33":"$32/100,"卖四:"$31":"$30/100,"卖三:"$29":"$28/100,"卖二:"$27":"$26/100,"卖一:"$25":"$24/100,"现价:"$7":"$4,"买一:"$15":"$14/100,"买二:"$17":"$16/100,"买三:"$19":"$18/100,"买四:"$21":"$20/100,"买五:"$23":"$22/100}'|while read line
        do

                local data=($(echo "$line"))
                local kpj=${data[0]##*:}
                for i in ${data[@]:1}
                do
                        local iArray=(${i//:/ })
                        local color="$(Color_Select ${iArray[1]} $kpj)"
                        case $Color in 
                                on)local g=2;;
                                ON)local g=1;;
                                *)local color=37;local g=2;;
                        esac
                        echo "${color} ${g} ${iArray[@]}"
                done|awk 'BEGIN{print "--------------------"}{printf("\033[0;%s;%sm%s     %5.2f  %s\n",$1,$2,$3,$4,$5)}END{printf("\033[0m")}END{{print "--------------------"}}'
        done
}
        dataTmp1=$(F_tmp_1 $*)
        dataTmp2=$(F_tmp_2 $*)
}
Data_Display(){
        clear
        echo -e "股票代码     涨幅%     涨跌   现在价格   股票名字\n$dataTmp1"
}
Data_Display2(){
        echo -e "$dataTmp2"
}
Stock_Code_Filter(){
        local stockCode="$*"
        for i in $stockCode
        do
                if [[ "$i" =~ ^[0-9]{6}$ ]];then
                        case $i in
                                0*|3*)i="sz$i";;
                                6*)i="sh$i";;
                                *)i="sz$i sh$i";;
                        esac
                        echo $i
                elif [[ "$i" =~ ^[a-z]{2}[0-9]{6}$ ]];then
                        echo $i
                fi
        done|tr "\n" " "
}
User_Data_Update(){
        local userDataBase64=`echo -n "${userDataArray[@]}"|tr " " "\n"|sort|uniq|tr "\n" " "|base64|tr -d "\n"`
        sed -r -i "/^$userName:/s/(^$userName:.+:)(.*)/\1$userDataBase64/" $userDataFile
}
User_Data_Add(){
        read -p "输入股票代码(多个用空格分割) : " stockAdd
        stockAdd="`Stock_Code_Filter $stockAdd`"
        userDataArray=(${userDataArray[@]} $stockAdd)
        User_Data_Update
}
User_Data_Del(){
        read -p "输入股票代码(多个用空格分割) : " stockDel
        stockDel="`Stock_Code_Filter $stockDel`"
        for i in $stockDel
        do
                userDataArray=(${userDataArray[@]/$i/})
        done
        User_Data_Update
}
Data_Select(){
        stockSelect=`echo -n "$stockSelect"|tr -s " "|tr " " "|"`
        Data_Update ${userDataArray[@]} 
        Data_Proces $stockSelect
        Data_Display 
        Data_Display2 
        local option=""
        read -t $updateTime -p "返回R : " option
        case $option in
                r|R)Print_Option;;
                *)local dateStatus=0;Data_Select;;
        esac
}
Print_Option(){
        Data_Update ${userDataArray[@]}
        Data_Proces
        Data_Display 
        local option=""
        local dateStatus=1
        read -t $updateTime -p "颜色C 增加A 删除D 查看S 退出Q : " option
        case $option in
                a|A)User_Data_Add;Print_Option;;
                d|D)User_Data_Del;Print_Option;;
                c|C)read -p "颜色开关(on|ON|off) : " Color;Print_Option;;
                s|S)read -p "输入股票代码(多个用空格分割) : " stockSelect;Data_Select;;
                q|Q)Clean_End;;
                *)local dateStatus=0;Print_Option
        esac
}
Check_Init(){
        which curl &>/dev/null
        if [ $? != 0 ];then
                echo "curl not install";exit 1
        fi
        local code=`curl -o /dev/null -s -w %{http_code} "${url}sh000001"`
        if [ "$code" != 200 ];then
                echo "url $url http code $code error";exit 1
        fi
}
Clean_End(){
        echo "End"
        exit 0
}

main(){
        url="http://hq.sinajs.cn/list="
        updateTime=${1}
        updateTime=${updateTime:=10}
        Color=$2
        Color=${Color:=off}
        Check_Init
        dirName="`cd $(dirname $0);pwd`"
        userDataFile=$dirName/.stockUser.data
        User_Manage
        trap 'Clean_End' INT
        Print_Option
        Clean_End
}
stty erase "^H"
main $*
