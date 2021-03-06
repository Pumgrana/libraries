#!/bin/bash

TEMPLATE="dbpedia_record.template"
ML="dbpedia_record.ml"
MLI="dbpedia_record.mli"
MODEL="dbpedia_record.model"

to_key () {
    str="$1"
    first=`echo "$str" | sed -e "s/^\(.\)\(.*\)/\1/g"`
    rest_tmp=`echo "$str" | sed -e "s/^.//g"`
    upper_case=`echo "$first" | tr '[a-z]' '[A-Z]'`
    rest=`echo "$rest_tmp" | sed -e "s/\(.*\)_\(.*\)/\1/g"`
    rest2=`echo "$rest_tmp" | sed -e "s/\(.*\)_\(.*\)/\2/g"`
    if [ "$rest" != "$rest2" ]; then
        ret=$(to_key "$rest2")
        echo "$upper_case$rest$ret"
    else
        echo "$upper_case$rest"
    fi
}

i=0
part=0
comment=false
type_i=0
key_i=0
declare -a FIELD_ARRAY
declare -a KEY_ARRAY
declare -a TYPE_ARRAY
declare -a GETTER_ARRAY
declare -a TYPE_NAME_ARRAY
declare -a TYPE_KEY_ARRAY
while read line ; do
    i=$(($i+1));

    save_bool=$comment

    TMP=`echo "$line" | grep "(\*"`
if [ -n "$TMP" ] || [ "$line" == "" ]
then comment=true
else

    comment=false

    if [ "$save_bool" != "$comment" ] ; then
        part=$(($part+1));
    fi

    if [ "$part" == "1" ] ; then

        # echo "Keys";
        TMP=`echo "$line" | sed -e "s/[\(\)]//g"`
        FIELD_ARRAY[$key_i]=`echo "$TMP" | sed -e "s/,.*//g"`
        key=$(to_key "${FIELD_ARRAY[$key_i]}")
        KEY_ARRAY[$key_i]=$key
        TYPE_ARRAY[$key_i]=`echo "$TMP" | sed -e "s/^[^,]*, \?//g" -e "s/,.*//g"`
        GETTER_ARRAY[$key_i]=`echo "$TMP" | sed -e "s/.*, \?//g"`
        # echo "field '${FIELD_ARRAY[$key_i]}'"
        # echo "key '${KEY_ARRAY[$key_i]}'"
        # echo "type '${TYPE_ARRAY[$key_i]}'"
        # echo "getter '${GETTER_ARRAY[$key_i]}'"

        key_i=$(($key_i+1));

    elif [ "$part" == "2" ]; then

        # echo "Types"
        TYPE_NAME=`echo "$line" | sed -e "s/:.*//g"`
        TMP=`echo "$line" | sed -e "s/.*\[//g" -e "s/\].*//g"`
        TYPE_NAME_ARRAY[$type_i]="$TYPE_NAME"
        # echo "$TYPE_NAME"

        set -f
        IFS=';'
        y=0
        declare -a TMP_KEY_ARRAY
        unset 'TMP_KEY_ARRAY[@]::10000'
        for x in $TMP; do
            TMP2=`echo "$x" | sed -e "s/ //g"`
            key_name=$(to_key "$TMP2")
            TMP_KEY_ARRAY[$y]="$key_name"
            # echo "$key_name"
            y=`expr $y + 1`
        done

        TYPE_KEY_ARRAY[$type_i]="${TMP_KEY_ARRAY[@]}"

        type_i=$(($type_i+1));

    fi

    # echo "$line";
fi

done < $MODEL

get_type () {
    key="$1"

    i=0
    for k in "${KEY_ARRAY[@]}"; do
        # echo "k $i [$key] == [$k]"
        if [ "$key" == "$k" ] ; then
            echo ${TYPE_ARRAY[$i]}
            return ;
        fi
        i=$(($i+1));
    done

}

get_getter () {
    key="$1"

    i=0
    for k in "${KEY_ARRAY[@]}"; do
        # echo "k $i [$key] == [$k]"
        if [ "$key" == "$k" ] ; then
            echo ${GETTER_ARRAY[$i]}
            return ;
        fi
        i=$(($i+1));
    done

}


i=0
key_list=""
data_list=""
declare -a MODULE_ARRAY
declare -a MODULE_SIG_ARRAY
for a in "${FIELD_ARRAY[@]}"; do

    field=${FIELD_ARRAY[$i]}
    key=$(to_key "$field")
    type=${TYPE_ARRAY[$i]}
    func=`echo "$type" | tr '[:upper:]' '[:lower:]'`
    func=`echo "$func" | sed -e "s#\.#_#g"`
    test_list=`echo "$func" | grep " list"`
    if [ "$test_list" != "" ]; then
        func=`echo "$func" | sed -e "s# list##g"`
        func="(to_list "$func"_of_string)"
    else
        func="to_$func"
    fi
    getter=${GETTER_ARRAY[$i]}
    if [ "$key_list" != "" ]; then
        key_list="$key_list | "
    fi
    key_list="$key_list$key"
    data_list="$data_list | $key -> ($func, \"$field\")\n"

    i=$(($i+1));

done

i=0
for tkeys in "${TYPE_KEY_ARRAY[@]}"; do

    type_name=${TYPE_NAME_ARRAY[$i]}
    keys=$(echo $tkeys | tr " " "\n")
    sig_name=`echo "$type_name" | tr '[:lower:]' '[:upper:]'`

    set -f
    IFS='
'
    record=""
    module_key=""
    module_getters=""
    for k in $keys; do

        if [ "$module_key" != "" ]; then
            module_key="$module_key;"
        fi
        module_key="$module_key Generic.$k"

        if [ "$record" != "" ]; then
            record="$record;"
        fi
        # echo "call [$k]"
        getter=$(get_getter $k)
        type=$(get_type $k)
        func=`echo "$type" | tr '[:upper:]' '[:lower:]'`
        func=`echo "$func" | sed -e "s#\.#_#g"`
        test_list=`echo "$func" | grep " list"`
        if [ "$test_list" != "" ]; then
            func=`echo "$func" | sed -e "s# list##g"`
            func="(get_list get_"$func")"
        else
            func="get_$func"
        fi
        func="(get_type $func)"
        record="$record $getter : $type"

        if [ "$module_getters" != "" ]; then
            module_getters="$module_getters;"
        fi
        module_getters="$module_getters $getter = Generic.($func keys v $k)"

    done

    sig="module type $sig_name =\nsig\ntype t = {$record}\nval parse: Rdf_sparql.solution list -> t list\nend;;";
    MODULE_ARRAY[$i]="\n$sig\n\nmodule $type_name : $sig_name =\nstruct\ntype t = {$record}\nlet keys = [$module_key]\nlet parse solutions =\nlet values = Generic.parse keys solutions in\nList.map (fun v -> {$module_getters}) values\nend;;\n"
    MODULE_SIG_ARRAY[$i]="\n$sig\nmodule $type_name : $sig_name\n"

    i=$(($i+1));

done

modules="${MODULE_ARRAY[@]}"
cat $TEMPLATE | sed -e "s#\%\%KEY_LIST\%\%#$key_list#g" -e "s#\%\%DATA_LIST\%\%#$data_list#g" -e "s#\%\%MODULES\%\%#$modules#g" > $ML

sig_modules="${MODULE_SIG_ARRAY[@]}"
echo -e "$sig_modules" > $MLI