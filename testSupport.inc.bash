# shellcheck disable=all
# source this file - not a script to run directly
{
    echo "❓  | Deprecated - use 'lib-testing.inc.bash' instead of 'utils.inc.bash'"
    echo "❓  | Path:"
    for x in "${BASH_SOURCE[@]}" ; do
        echo "❓  |   - $x"
    done
} >&2

libSupport_testName=""
libSupport_testCmd=""
libSupport_testVerificationResult=""

libSupport_testDir=$(mktemp -d -t tmp_testComparisons_XXXXXX) || {
    echo "❌ Failed to create temporary directory for tests"
    exit 1
}

function makeNamedNonUniqueTempFile()
{
    local suffix="${1:-.tmp}"
    local sanitised_fname="${libSupport_testName//:/_}${suffix}"
    sanitised_fname="${sanitised_fname//\//_}"
    sanitised_fname="${sanitised_fname//\#/_}"
    sanitised_fname="${sanitised_fname//\[/}"
    sanitised_fname="${sanitised_fname//\]/}"
    sanitised_fname="${sanitised_fname//\ /_}"

    local fullPath="${libSupport_testDir%/}/${sanitised_fname}"
    touch "$fullPath" || {
        echo "❌ Failed to create temporary file: $fullPath"
        exit 1
    }
    echo "$fullPath"
}

testSuffixCount=1
function startTestNamed()
{
    local testName=''
    local testSuffix=''
    for sourceFile in "${BASH_SOURCE[@]}" ; do
        if [[ "$sourceFile" == "./test_"* ]] ; then
            testName="${sourceFile##*/test_}"
            testName="${testName%.sh}"  # Remove the .sh extension
            break
        fi
    done

    if [[ -n "${1:-}" ]] ; then
        [[ -n "$testName" ]] && testName="${testName}:"
        testName="${testName}"

        testSuffix="${1/\[++\]/"[#${testSuffixCount}]"}"

        [[ "$testSuffix" == "$1" ]] || ((testSuffixCount++))
    fi
    libSupport_testName="${testName}${testSuffix}"
    libSupport_testCmd=""
    libSupport_testVerificationResult=""
}
function setTestName()
{
    # |Logging| echo "!!!!!!!!!!!!!!!!!! DEPRECATED setTestName() - use startTestNamed() instead !!!!!!!!!!!!!!!!!!"
    libSupport_testName="${1}"
}

PRINT_TEST_LEFT_OFFSET=34
PRINT_LEFT_PREFIX="$(printf '                %-*s' "$PRINT_TEST_LEFT_OFFSET" '')"

function printTestFailed()
{
    local msg="${1:-}"
    local msg2="${msg% | cat}"
    local msg3="${msg##      }"
    printf "❌ Test failed: %-*s │ %s\n" "$PRINT_TEST_LEFT_OFFSET" "$libSupport_testName" "${msg3}"
}
function printTestPassed()
{
    local msg="${1:-}"
    local msg2="${msg% | cat}"
    local msg3="${msg##      }"
    printf "✅ Test passed: %-*s │ %s\n" "$PRINT_TEST_LEFT_OFFSET" "$libSupport_testName" "${msg3}"
}

function printTestFollowupLine()
{
    local msg="${1:-}"
    printf "%s │ %s\n" "$PRINT_LEFT_PREFIX" "${msg}"
}

function markTestCompleteAndFailed()
{
    # |Logging| echo "!!!!!!!!!!!(0) [$libSupport_testCmd]: libSupport_testVerificationResult=$libSupport_testVerificationResult"
    local msg="${1:-}"
    #|Already Printed| printTestFailed "${msg%}"
    if [[ "${TEST_SUPPORT_EXIT_ON_FAIL:-}" == "yes" ]] ; then
        echo "Exiting due to \`export TEST_SUPPORT_EXIT_ON_FAIL=yes\`"
        exit 1
    fi
    return 1
}

function markTestFail()
{
    local msg="${1:-}"
    libSupport_testVerificationResult="failed"
    printTestFailed "${msg}"
    return 1
}
function markFail_expected()
{
    libSupport_testVerificationResult="failed"
    local expected="$1"
    local actual="$2"


    printTestFailed "Actual❌: ${actual##stdOut: }"
    printTestFollowupLine "Expected: $(displayPath "${expected##      }")"

    return 1
}

function jq_normaliseWithChecks()
{
    local tmpIn ; tmpIn="$(makeNamedNonUniqueTempFile '-in.json')"
    local tmpOut ; tmpOut="$(makeNamedNonUniqueTempFile '-out.json')"

    cat > "$tmpIn"
    if ! jq -S .  2>/dev/null < "$tmpIn" > "$tmpOut" ; then

        cp "$tmpIn" "$tmpOut"

        local kind="$1"
        [[ -f "$failure_notes_file" ]] && echo "${kind} is not valid JSON" >> "$failure_notes_file"
        # |Logging| echo "❓❓  ${kind} is not valid JSON" >&2
    fi

    cat "$tmpOut"

    rm -f "$tmpOut"
    rm -f "$tmpIn"
}
# $1 = Generated Prefix
# $2 = Generated Output  Always '<file'
#
# $3 = Gold Prefix
# $4 = Gold Comparison: <file  or =value   (If neither - assumes a file)
#
# $5 = Optional filter to apply to generated output before comparison (e.g. 'json' or 'hex')

function verifyFile_matches() {
    local gen__prefix="${1%: }"
    local gen__fname="${2#<}"
    local gold_prefix="${3}"
    local gold_comparison="${4}"
    local filter="${5:-}"

    gen__fname="$(realpath -m "${2#<}")"


    [[ -f "$gen__fname" ]] || markTestFail "Expected file not found: ${gen__fname}" || return 1


    local gold_fname
    if [[ "${gold_comparison}" == '='* ]] ; then
        gold_fname="$(makeNamedNonUniqueTempFile '.expectedValue')"

        echo "${gold_comparison#=}" > "$gold_fname"
        gold_name="$(quoteIfNeeded "${gold_comparison#=}")"
    else
       [[ "$gold_comparison" == '<'* ]] || echo "ℹ️  TestSupport[Deprecated usage]:  Prefer '<$gold_comparison' to indicate a file"
       gold_fname="$(realpath -m "${gold_comparison#<}")"
       gold_name="${gold_fname##"${PWD%/}/"}"
    fi

    if [[ ! -f "$gold_fname" ]] ; then
        markTestFail "Gold file not found: ${gold_fname}"
        return 1
    fi



    if [[ "$filter" == "json" ]] ; then
        gen__fname_old="$gen__fname"
        gen__fname+="_modified"

        # |Logging| {
        # |Logging|     echo "----v"
        # |Logging|     cat "$gen__fname_old"
        # |Logging|     echo "<<< $gen__fname_old"
        # |Logging|     echo "----^"
        # |Logging| } | withPrefix "❓  " >&2

        jq_normaliseWithChecks "Generated output" < "$gen__fname_old" > "$gen__fname"
        gen__prefix+=".json"

        gold_fname_old="$gold_fname"
        gold_fname+="_modified"
        jq_normaliseWithChecks "Comparison value" < "$gold_fname_old" > "$gold_fname"
    elif [[ "$filter" == "hex" ]] ; then
        gen__fname_old="$gen__fname"
        gen__fname="$(makeNamedNonUniqueTempFile '.hexout')"
        xxd -ps < "$gen__fname_old" | tr -d '\n' > "$gen__fname"
        echo "" >> "$gen__fname" # Ensure file ends with newline for better diff display
        gen__prefix+=".hex"

    else
        [[ "$filter" == "text" ]] || [[ "$filter" == "direct" ]] || [[ "$filter" == "annotatedData" ]] || [[ -z "$filter" ]] || echo "ℹ️  Found '$filter' for filter - treating as 'direct' (no filtering)"
    fi

    local gen__name="${gen__prefix}: ${gen__fname##"${PWD%/}/"}"
    #|x| echo "gold_comparison=$gold_comparison | fname=$gold_fname"
    #|x| echo "Generated file: $gen__fname"

    if [[ "$gold_prefix" == "<auto>" ]] ; then
        gold_prefix="$(printf '%*s' "${#gen_prefix}" '')"
    fi


    gold_name="${gold_prefix}${gold_name}"

    # |Logging| echo "----------"
    # |Logging| cat "$gen__fname"
    # |Logging| echo "-- gold: $gold_comparison [${gold_comparison#=}] -- actual: $gen__fname"
    # |Logging| cat "$gold_fname"
    # |Logging| echo "-- failure notes : $failure_notes_file --"
    # |Logging| [[ -f "$failure_notes_file" ]] && cat "$failure_notes_file"
    # |Logging| echo "--------^"

    if ! cmp "$gen__fname" "$gold_fname" >/dev/null 2>/dev/null ; then
        markFail_expected "${gold_name}" "${gen__name}" "$filter" || true
        if [[ "$filter" == 'text' ]]|| [[ "$filter" == 'json' ]]; then
        {
            echo "---- Actual → Expected (Gold standard)     -----"
            diff -u "$gen__fname" "$gold_fname" | tail -n +3 || true
            echo "--------------"
        } | withPrefix "${PRINT_LEFT_PREFIX} │ "
        elif [[ "$filter" == "annotatedData" ]] ; then
        {
            echo "---- Actual → Expected (Gold standard)     -----"
            summary_fname_gen_="$(makeNamedNonUniqueTempFile '.gen_.summary.json')"
            echo "annotatedDataFile: hash=$(md5sum "$gen__fname" | awk '{print $1}')" >> "${summary_fname_gen_}"
            annotatedData export "$gen__fname" --outputFormat=json:summary | jq -S >> "$summary_fname_gen_"

            summary_fname_gold="$(makeNamedNonUniqueTempFile '.gold.summary.json')"
            echo "annotatedDataFile: hash=$(md5sum "$gold_fname" | awk '{print $1}')" >> "${summary_fname_gold}"
            annotatedData export "$gold_fname" --outputFormat=json:summary | jq -S >> "$summary_fname_gold"

            diff  "$summary_fname_gen_" "$summary_fname_gold" || true
            echo "--------------"
        } | withPrefix "${PRINT_LEFT_PREFIX} │ "
        fi
        return 0
    fi
    # |Logging| echo "!!!!!!!!!!!(2) [$libSupport_testCmd]:libSupport_testVerificationResult=$libSupport_testVerificationResult"

    if [[ "${gold_comparison}" == '='* ]] ; then
        # Cleaner value for display - remove newlines, carriage returns, and common error prefixes
        gold_name="Verified: $(quoteIfNeeded "$(echo "${gold_comparison#=}" | sed -e 's/\r.*\r//' -e 's/❌//' -e 's/Error://' -e 's/^ *//')")"
    fi

    printTestPassed "${gold_name}"

    return 0
}

function verifyValue_matchesValue() {
    local gen__prefix="${1}"
    local gen__value="${2}"
    local gold_prefix="${3}"
    local gold_value="${4}"

    local gen__name="${gen__prefix}${gen__value}"
    local gold_name="${gold_prefix}${gold_value}"

    [[ "$gen__value" == "$gold_value" ]] ||  markFail_expected "${gold_name}" "${gen__name}" || return 1

    local cleaner_value=''

    cleaner_value="$(echo "$gold_value" | sed -e 's/\r.*\r//' -e 's/❌//' -e 's/Error://' -e 's/^ *//')"

    printTestPassed "Verified: $(quoteIfNeeded "$cleaner_value")"

    return 0
}


function verifyStdIn_fullReply() {

    local actual_reply ; actual_reply="$(jq -c . | cat)"
    [[ "$actual_reply" == "$expected_reply" ]] ||  markFail_expected  "$expected_reply" "$actual_reply" || return 1

    printTestPassed "$actual_reply"

    return 0
}




################################################
#
# doTest_xxxxx
#

#|x| function doTest_verifyStdIn_cmdResponse() {
#|x|     startTestNamed "$1"
#|x|     local expected_cmd="$2"
#|x|     local expected_response="$3"
#|x|
#|x|     local expected_reply="{\"chosenCmd\":\"${expected_cmd}\""
#|x|
#|x|     [[ -n "$expected_response" ]] && expected_reply="${expected_reply},\"response\":${expected_response}"
#|x|     expected_reply="${expected_reply}}"
#|x|
#|x|     verifyStdIn_fullReply "$expected_reply" || return 1
#|x|     return 0
#|x| }
function quoteIfNeeded()
{
    local value
    local result=''

    for value in "$@" ; do
        [[ -n "$result" ]] && echo -n " "


        issues=''
        result="$value"

        [[ "$value" == ''    ]] && issues+='[empty]'
        [[ "$value" == *"'"* ]] && issues+='[singleQuotes]'
        [[ "$value" == *'"'* ]] && issues+='[doubleQuotes]'
        [[ "$value" == *" "* ]] && issues+='[spaces]'
        [[ "$value" == *'`'* ]] && issues+='[backticks]'
        [[ "$value" == *'$'* ]] && issues+='[dollarSigns]'
        [[ "$value" == *'|'* ]] && issues+='[pipes]'
        [[ "$value" == *'&'* ]] && issues+='[ampersands]'
        [[ "$value" == *'('* ]] && issues+='[openParens]'
        [[ "$value" == *')'* ]] && issues+='[closeParens]'
        [[ "$value" == *'{'* ]] && issues+='[openBraces]'
        [[ "$value" == *'}'* ]] && issues+='[closeBraces]'
        [[ "$value" == *'['* ]] && issues+='[openBrackets]'
        [[ "$value" == *']'* ]] && issues+='[closeBrackets]'


        if [[ -n "$issues" ]] ; then

            if [[ "$issues" != *'[singleQuotes]'* ]] ; then
                result="'${value}'"
            else
                result="$(printf "%q" "$value")"
            fi
            #|Logging| printf "ℹ️  Value \`%s\` will be quote protected: %s\n" "$value" "$result" >&2
        fi

        echo -n "$result"
    done
    return 0
}
function doTest_expectFailure()
{
    local stdIn="$1"
    local expected_cmd_code="$2"
    local expected_errout="$3"
    local cmd="$4"
    shift 4

    local test_name="${cmd##*/}[$*]"

    startTestNamed "$test_name"

    local stderr_file ; stderr_file="$(makeNamedNonUniqueTempFile '.stderr')"
    local stdout_file ; stdout_file="$(makeNamedNonUniqueTempFile '.stdout')"
    local failure_notes_file ; failure_notes_file="$(makeNamedNonUniqueTempFile '.failureNotes')"
    local cmd_result_code ; cmd_result_code=0

    libSupport_testCmd="$(quoteIfNeeded "$cmd" "$@")"
    if [[ -n "$stdIn" ]] ; then
        libSupport_testCmd="echo $(quoteIfNeeded "$stdIn") | ${libSupport_testCmd}"

        echo "$stdIn" | "$cmd" "$@" 1>"$stdout_file" 2>"$stderr_file" || cmd_result_code="$?"
    else
                        "$cmd" "$@" 1>"$stdout_file" 2>"$stderr_file" || cmd_result_code="$?"
    fi

    verifyValue_matchesValue "stderr:" "$(<"$stderr_file")" "" "${expected_errout}" || true

    commandComplete_dumpCmdInfo "$cmd_result_code" "$expected_cmd_code"
}

function doTest_expectFailure_01()
{
    local stdin="$1"
    shift 1
    doTest_expectFailure "$stdin" 1 "$@" || return 1
    return 0
}


function doTest_Cmd_check_stdOut_contents_hex()
{
    doTestNamed_check_stdOut_contents_hex "${3:-}[++]" "$@" #:hex_test[++]" "$@"
    return "$?"
}

function doTest_check_stdOut_file()
{
    doTestNamed_check_stdOut_file "${3:-}[++]" "$@" #:stdout[++]" "$@"
    return "$?"
}

function doTest_check_stdOut_json()
{
    startTestNamed "${3:-}[++]" #:stdout_json[++]"

    doCmd_check_stdOut json "$@"
    return "$?"
}
################################################
#
# doTestNamed_xxxxx
#
function doTestNamed_check_stdOut_file()
{
    startTestNamed "${1}"
    shift 1

    doCmd_check_stdOut direct "$@"
    return "$?"
}

function doTestNamed_check_stdOut_contents_hex()
{
    startTestNamed "${1}"
    shift 1

    doCmd_check_stdOut hex "$@"
    return "$?"
}


################################################
#
# doCmd_xxxxx
#

function doCmd_check_stdOut()
{
    local filter="${1}"
    local input="${2}"
    local expected_fileOrValue="${3}"
    local cmd="$4"
    shift 4

    ##################################################################
    #
    local stderr_file ; stderr_file="$(makeNamedNonUniqueTempFile '.stderr')"
    local stdout_file ; stdout_file="$(makeNamedNonUniqueTempFile '.stdout')"
    local failure_notes_file ; failure_notes_file="$(makeNamedNonUniqueTempFile '.failureNotes')"
    local formatted_stdout="$stdout_file"
    local cmd_result_code ; cmd_result_code=0

    libSupport_testCmd="$(quoteIfNeeded "$cmd" "$@")"
    if [[ "$input" == '<'* ]] ; then
        input_file="${input#<}"
        libSupport_testCmd="${libSupport_testCmd} < \"$input_file\""
    else
        input_file="/dev/stdin"
    fi
    libSupport_testCmd="${libSupport_testCmd} | cat"
    "$cmd" "$@" < "$input_file" 1>"$stdout_file" 2>"$stderr_file" || cmd_result_code="$?"

    # |Logging| echo "Running[a]: $libSupport_testCmd"
    #
    ###################################################################
    # |Logging| echo "!!!!!!!!!!!(3) [$libSupport_testCmd]:libSupport_testVerificationResult=$libSupport_testVerificationResult"

    local gen_prefix='stdOut'
    verifyFile_matches "${gen_prefix}: " "${stdout_file}" "<auto>" "${expected_fileOrValue}" "$filter"
    #|x| xxd -i -R never -ps < "$stdout_file" | tr -d '\n' > "$hexout_file"

    # |Logging| echo "!!!!!!!!!!!(4) [$libSupport_testCmd]libSupport_testVerificationResult=$libSupport_testVerificationResult"
    commandComplete_dumpCmdInfo "$cmd_result_code"
}

function doCmd_check_stdOut_json()
{
    doCmd_check_stdOut json '' "$@"
}


#|x| function doCmd_check_stdOut_contents()
#|x| {
#|x|     local input="${1}"
#|x|     local expected_contents="${3}"
#|x|     local cmd="$3"
#|x|     shift 3
#|x|
#|x|     ##################################################################
#|x|     #
#|x|     local stderr_file ; stderr_file="$(makeNamedNonUniqueTempFile '.stderr')"
#|x|     local stdout_file ; stdout_file="$(makemakeNamedNonUniqueTempFileTempFile '.stdout')"
#|x|     local cmd_result_code ; cmd_result_code=0
#|x|
#|x|     libSupport_testCmd="$(quoteIfNeeded "$cmd" "$@")"
#|x|
#|x|     if [[ "$input" == '<'* ]] ; then
#|x|         input_file="${input#<}"
#|x|         libSupport_testCmd="${libSupport_testCmd} < \"$input_file\""
#|x|     else
#|x|         input_file="/dev/stdin"
#|x|     fi
#|x|     "$cmd" "$@" < "$input_file" 1>"$stdout_file" 2>"$stderr_file" ; cmd_result_code="$?"
#|x|
#|x|     #
#|x|     ###################################################################
#|x|     verifyValue_matchesValue "stdout:" "$(< "$stdout_file")" "" "${expected_contents}"
#|x|
#|x|     commandComplete_dumpCmdInfo "$cmd_result_code"
#|x| }
#|x|
#|x| function doCmd_check_stdOut_contents_hex()
#|x| {
#|x|     local input="${1}"
#|x|     local expected_contents_hex="${2}"
#|x|     local cmd="$3"
#|x|     shift 3
#|x|
#|x|     local hexout_file ; hexout_file="$(makeNamedNonUniqueTempFile '.hexout')"
#|x|
#|x|     ##################################################################
#|x|     #
#|x|     local stderr_file ; stderr_file="$(makeNamedNonUniqueTempFile '.stderr')"
#|x|     local stdout_file ; stdout_file="$(makeNamedNonUniqueTempFile '.stdout')"
#|x|     local cmd_result_code ; cmd_result_code=0
#|x|
#|x|     libSupport_testCmd="$(quoteIfNeeded "$cmd" "$@")"
#|x|     if [[ "$input" == '<'* ]] ; then
#|x|         input_file="${input#<}"
#|x|         libSupport_testCmd="${libSupport_testCmd} < \"$input_file\""
#|x|     else
#|x|         input_file="/dev/stdin"
#|x|     fi
#|x|
#|x|     "$cmd" "$@" < "$input_file" 1>"$stdout_file" 2>"$stderr_file" ; cmd_result_code="$?"
#|x|
#|x|     #
#|x|     ###################################################################
#|x|     #|x| xxd -i -R never -ps < "$stdout_file" | tr -d '\n' > "$hexout_file"
#|x|     xxd -i -ps < "$stdout_file" | tr -d '\n' > "$hexout_file"
#|x|
#|x|     verifyValue_matchesValue "hexout:" "$(< "$hexout_file")" "hexout:" "${expected_contents_hex}"
#|x|     commandComplete_dumpCmdInfo "$cmd_result_code"
#|x| }

function commandComplete_dumpCmdInfo()
{
    local cmd_result_code="$1"
    local expected_return_code="${2:-}"

    local pre_gap
    # |Logging| echo "!!!!!!!!!!!(5) [$libSupport_testCmd]:libSupport_testVerificationResult=$libSupport_testVerificationResult"
    echo -e "${PRINT_LEFT_PREFIX} │ Command: ${COLOUR[VIVID_BLUE_STDOUT]:-}${libSupport_testCmd% | cat}${COLOUR[OFF_STDOUT]:-}"
    sed --unbuffered -e 's/\r.*\r//' -e "s|^⚠️|⚠ |g"  -e "s|^❌|✗ |g" -e "s|^ℹ️ |🛈 |g"  -e "s/^/${PRINT_LEFT_PREFIX} │  /" < "$stderr_file"
    sed --unbuffered -e 's/\r.*\r//' -e "s/^/${PRINT_LEFT_PREFIX} │ ❓  /" < "$failure_notes_file"


    [[ -z "$expected_return_code" ]] && expected_return_code="${EXPECTED_CMD_RETURN_CODE:-0}"


    local expected_msg=""
    [[ "${expected_return_code}" == "0" ]] || expected_msg="(Expected $expected_return_code)"

    if [[ "$cmd_result_code" == "$expected_return_code" ]] ; then
        [[ -n "$expected_msg" ]] && echo "${PRINT_LEFT_PREFIX} │ └─ ✓ Return value: $cmd_result_code $expected_msg"
    else
        echo "${PRINT_LEFT_PREFIX} │ └─ ✗ Return value: $cmd_result_code $expected_msg"
        markTestFail  "Command returned with code $cmd_result_code $expected_msg"
    fi
    # |Logging| echo "!!!!!!!!!!!(6) [$libSupport_testCmd]:libSupport_testVerificationResult=$libSupport_testVerificationResult"

    if [[ "$libSupport_testVerificationResult" == "failed" ]] ; then
        # |Logging| echo "!!!!!!!!!!!(7) [$libSupport_testCmd]:libSupport_testVerificationResult=$libSupport_testVerificationResult"
        markTestCompleteAndFailed  "Command: ${libSupport_testCmd}"
    fi
}



#
################################################

didFail='no'

function RunWithNoteFailure()
{

    "$@" && return 0

    didFail='yes'

    if [[ "${TEST_SUPPORT_EXIT_ON_FAIL:-}" == "yes" ]] ; then
        echo -e "Exiting due to ${COLOUR[VIVID_BLUE_STDOUT]:-}export TEST_SUPPORT_EXIT_ON_FAIL=yes${COLOUR[OFF_STDOUT]:-}"
        exit 1
    else
        echo -e "   Use: ${COLOUR[VIVID_BLUE_STDOUT]:-}export TEST_SUPPORT_EXIT_ON_FAIL=yes${COLOUR[OFF_STDOUT]:-} to exit on first failure"
        return 1
    fi
}


function ReportFailures()
{
    [[ "$didFail" == 'no' ]] && return 0

    echo "❌ Failure(s) detected during test: $*"
    [[ "${TEST_SUPPORT_EXIT_ON_FAIL:-}" == "yes" ]] || echo "   Use: \`export TEST_SUPPORT_EXIT_ON_FAIL=yes\` to exit on first failure"

    return 1
}

function doValidateAnnotatedFile()
{
    #
    # Validates the annotated file against:
    #  * (fname).raw/bin/img_* - the raw data
    #  * (fname).summary.json  - the expected json summary
    #  * (fname).png           - the expected image export
    #
    local annotated_file="${1}"
    local raw_format=''

    raw_format="$(annotatedData export "${annotated_file}" --outputFormat=json:summary | jq -r .bitstream.format)"
    raw_format="${raw_format##*/}"
    [[ -z "$raw_format" ]] && raw_format='raw'

    local fname_noext="${annotated_file%%.*}"
    #                   +--------------------+----------------------------+-----------------------------------+--------------------------------------------------------------------------------
    #                   | Test Kind          | Input                ------| Expected Output                   | Command to Run
    #                   +--------------------+----------------------------+-----------------------------------+--------------------------------------------------------------------------------
    RunWithNoteFailure   doTest_check_stdOut  "<${annotated_file}"          "<${fname_noext}.${raw_format}"     annotatedData export  -f bitstream
    RunWithNoteFailure   doTest_check_stdOut  "<${annotated_file}"          "<${fname_noext}.summary.json"      annotatedData export  -f json:summary
    RunWithNoteFailure   doTest_check_stdOut  "<${annotated_file}"          "<${fname_noext}.png"               annotatedData export  -f image
    return 0
}

function doTest_compare_annotated_files()
{
    startTestNamed "${3:-}[++]"

    doCmd_check_stdOut annotatedData "$@" || true
}

if [[ -n "${EXE_DIR:-}" ]] ; then
    export PARENT_DIR ; PARENT_DIR="$(dirname "${EXE_DIR}")"
    export SAMPLES_DIR="${PARENT_DIR}/samples"

    set +e
fi
