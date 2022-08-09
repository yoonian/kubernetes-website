#!/bin/bash
#
# This script updates static/_redirects according to English version.
#
# TODO: Use assoicate map in Bash 4.0
#

function generateTestFile() {
  cat <<'END' > test
/docs/     /docs/home/ 301!
/zh/docs/
/docs/reference/kubectl/overview/    /docs/reference/kubectl/ 301
# /zh-cn/docs/admin/extensible-admission-controllers.md     /zh-cn/docs/reference/access-authn-authz/extensible-admission-controllers/ 301
# /id/docs/admin/cluster-management/     /id/docs/tasks/administer-cluster/ 302
# /pt/*         /pt-br/:splat  302!
# /docs/tasks/administer-cluster/developing-cloud-controller-manager.md     /docs/tasks/administer-cluster/developing-cloud-controller-manager/ 301
# /docs/tasks/administer-cluster/default-cpu-request-limit/     /docs/tasks/configure-pod-container/assign-cpu-resource/#specify-a-cpu-request-and-a-cpu-limit/ 301
# /docs/tasks/administer-cluster/default-memory-request-limit/     /docs/tasks/configure-pod-container/assign-memory-resource/#specify-a-memory-request-and-a-memory-limit/ 301
# /docs/user-guide/kubectl/kubectl_*     /docs/reference/generated/kubectl/kubectl-commands#:splat 301
# /docs/tasks/tools/install-minikube/     https://minikube.sigs.k8s.io/docs/start/     302
# /docs/reference/generated/kubernetes-api/v1.15/    https://v1-15.docs.kubernetes.io/docs/reference/generated/kubernetes-api/v1.15/  301
# /security/ /docs/reference/issues-security/security/ 302
# /docs/reference/generated/cloud-controller-manager/     /docs/reference/command-line-tools-reference/cloud-controller-manager/ 301
# /docs/home/contribute/create-pull-request/ /docs/contribute/start/ 301
# /docs/contribute/create-pull-request/     /docs/home/contribute/create-pull-request/ 301
# /docs/contribute/page-templates/     /docs/home/contribute/page-templates/ 301
# /docs/home/contribute/review-issues/ /docs/contribute/intermediate/ 301
# /docs/contribute/review-issues/     /docs/home/contribute/review-issues/ 301
# /docs/contribute/stage-documentation-changes/     /docs/home/contribute/stage-documentation-changes/ 301
# /docs/contribute/style-guide/     /docs/home/contribute/style-guide/ 301
# /docs/contribute/write-new-topic/        /docs/home/contribute/write-new-topic/ 301
# /docs/contribute/start/        /docs/contribute/ 301
# /docs/setup/learning-environment/minikube/  /docs/tasks/tools/ 302
# /id/docs/setup/learning-environment/minikube/  /id/docs/tasks/tools/ 302
END
}

function usage() {
  echo -e "\nThis script updates static/_redirects according to English version" >&2
  echo -e "Usage:\n\t$0 [run|test|diff]\n" >&2
  exit 1
}

if [ "$#" -ne 1 ] ; then
  usage
fi

case "${1}" in
"test-ready")
  generateTestFile
  FILE=test
  ;;
"test")
  generateTestFile
  ${0} test-ready
  rm test
  exit 0
  ;;
"run")
  FILE=static/_redirects
  ;;
"diff")
  ${0} run > x
  cat x | sort > x.sorted
  cat x.sorted | uniq > x.uniq
  rm x
  diff x.sorted x.uniq
  rm x.sorted x.uniq
  exit 0
  ;;
*)
  usage
  ;;
esac

ROOT=$(pwd)
LANGS=$(ls content | grep -v en)
VIRTUAL_LANGS=(${LANGS[@]} zh pt)

cat ${FILE} | while true; do
  function has() {
    eval "V=$(echo \${${1}_${2//[:\/\*\-\.]/_}})"
    if [ "${V}" == "" ]; then
       return 0
    fi
    return 1
  }

  function generateLinks() {
    URI="${1}"
    DOC="${2}"
    for LANGUAGE in ${LANGS[@]}; do
      LANG_URI="/${LANGUAGE}${URI}"
      has "O" "${LANG_URI}"
      if [ ${?} == 0 ]; then
        ADD=0
        LANG_DOC="${LANGUAGE}${DOC}"
        if [ -e "${ROOT}/content/${LANG_DOC%?}.md" ] || [ -d "${ROOT}/content/${LANG_DOC}" ]; then
          ADD=1
        else
          has "E" "${URI}"
          if [[ ${?} == 0 ]]; then
            ADD=1
          fi
        fi
        if [[ ${ADD} == 1 ]]; then
          eval "O_${LANG_URI//[:\/\*\-\.]/_}=1"
          MODIFED_LINE=${LINE}
          MODIFED_LINE=${MODIFED_LINE/"$DOC" /"/$LANG_DOC" }
          MODIFED_LINE=${MODIFED_LINE/"$URI"/"$LANG_URI"}
          echo "${MODIFED_LINE}"
        fi
      fi
    done
  }

  while read -r LINE; do
    TOKEN=(${LINE})
    URI=${TOKEN[0]}
    DOC=${TOKEN[1]/\#*/}
    case "${URI}" in
    # english baseline
    /docs/*)
      echo "${LINE}"
      eval "E_${URI//[:\/\*\-\.]/_}=1"
      generateLinks "${URI}" "${DOC}"
      ;;

    # non-english
    /*)
      PROCESSED=0
      for LANGUAGE in ${VIRTUAL_LANGS[@]}; do
        if [[ "${URI}" == "/${LANGUAGE}/"* ]]; then
          PROCESSED=1
          has "O" "${URI}"
          if [ ${?} == 0 ]; then
            eval "O_${URI//[:\/\*\-\.]/_}=1"
            echo "${LINE}"
            break
          fi
        fi
      done
      if [ ${PROCESSED} == 0 ]; then
        echo "${LINE}"
        generateLinks "${URI}" "${DOC}"
      fi
      ;;

    *)
      echo "${LINE}"
      ;;
    esac

  done
  break
done

exit 0
