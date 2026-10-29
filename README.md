# Лабораторная работа 4: Terraform и Yandex Cloud

## Результаты выполнения 29.10.2026

Работа выполнена, все 8 ресурсов лабораторной удалены.
Одностраничный [отчёт с результатами](reports/lab-04-report.pdf) включён в репозиторий.

Фактические итоги команд:

```text
terraform plan:
Plan: 8 to add, 0 to change, 0 to destroy.

terraform apply lab.tfplan:
Apply complete! Resources: 8 added, 0 changed, 0 destroyed.

terraform plan (повторный):
No changes. Your infrastructure matches the configuration.

terraform destroy:
Destroy complete! Resources: 8 destroyed.

yc compute instance list (после удаления):
+----+------+---------+--------+-------------+-------------+
| ID | NAME | ZONE ID | STATUS | EXTERNAL IP | INTERNAL IP |
+----+------+---------+--------+-------------+-------------+
+----+------+---------+--------+-------------+-------------+
```

nginx на web ответил `HTTP/1.1 200 OK`. Подключение к worker через web
прошло успешно; `lab-worker.service` имел статус `active (running)` и писал
задачи в `/var/log/worker.log` раз в минуту. У worker публичный IP отсутствовал.

## Конфигурация

Одна VPC, подсеть 10.10.0.0/24 в ru-central1-a, две ВМ Ubuntu 22.04 LTS
(2 vCPU, 2 ГБ RAM, 20% гарантированной доли CPU), две группы безопасности.
web запускает nginx в Docker на порту 8080. worker запускает Python-процесс
через systemd и записывает строку в /var/log/worker.log раз в минуту.

web имеет публичный IP. worker имеет только внутренний IP и принимает SSH
только из подсети лабораторной. NAT-шлюз и таблица маршрутизации дают worker
исходящий доступ к репозиториям пакетов без публичного IP. Всего 8 управляемых
ресурсов Terraform; загрузочные диски создаются в составе ВМ.

## Подготовка

Нужны Terraform >= 1.5, Yandex Cloud CLI, настроенный `yc init`, активный
платёжный аккаунт и SSH-ключ `~/.ssh/terraform_lab` с публичной частью `.pub`.
ВМ, диски, публичный IP и сетевые сервисы могут тарифицироваться.

В том же терминале, где будут запускаться команды Terraform:

```bash
export YC_TOKEN="$(yc iam create-token)"
export YC_CLOUD_ID="$(yc config get cloud-id)"
export YC_FOLDER_ID="$(yc config get folder-id)"
```

Токены и идентификаторы облака/каталога в исходниках отсутствуют.
После истечения токена повторить первую команду. Параметры инфраструктуры
объявлены в variables.tf. При необходимости переопределять через `-var` или
локальный terraform.tfvars, который исключён из Git.

## Проверка и создание

```bash
terraform init
terraform fmt -check
terraform validate
mkdir -p logs
set -o pipefail
terraform plan -no-color -out=lab.tfplan | tee logs/01-plan.txt
terraform apply -no-color lab.tfplan | tee logs/02-apply.txt
terraform plan -no-color | tee logs/03-plan-repeat.txt
```

Перед apply проверить план: ожидается `8 to add, 0 to change, 0 to destroy`.
Повторный план должен показать `No changes`. apply создаёт платные ресурсы.
Не применять конфигурацию при неожиданных удалениях или изменениях.
Сохранённый план может содержать метаданные: не включать в сдачу.

## Проверка ВМ

Первичная установка cloud-init может занять несколько минут после apply.

```bash
WEB_IP="$(terraform output -raw web_public_ip)"
WORKER_IP="$(terraform output -raw worker_private_ip)"
ssh -i ~/.ssh/terraform_lab ubuntu@"$WEB_IP" 'sudo cloud-init status --wait'
curl "http://$WEB_IP:8080"
ssh -i ~/.ssh/terraform_lab ubuntu@"$WEB_IP" 'sudo docker ps'
ssh -i ~/.ssh/terraform_lab -o "ProxyCommand=ssh -i ~/.ssh/terraform_lab -W %h:%p ubuntu@$WEB_IP" ubuntu@"$WORKER_IP"
```

На worker выполнить:

```bash
sudo cloud-init status --wait
sudo systemctl status lab-worker --no-pager
sudo tail /var/log/worker.log
exit
```

Приватный ключ остаётся на локальном компьютере, ProxyCommand использует web
как SSH-посредника. На первой попытке проверить и подтвердить SSH fingerprint.
В `yc compute instance list` у worker поле EXTERNAL IP должно быть пустым.
Если cloud-init завершился с ошибкой, проверить `/var/log/cloud-init-output.log`
на соответствующей ВМ.

## Удаление и сдача

```bash
terraform plan -destroy -out=destroy.tfplan
terraform apply -no-color destroy.tfplan | tee logs/04-destroy.txt
yc compute instance list | tee logs/05-instances.txt
```

Ожидается `Destroy complete! Resources: 8 destroyed.` и пустой список ВМ,
если в каталоге нет других машин. Это сохранённый destroy-план; если требуется
именно команда `terraform destroy` для отчёта, вместо двух первых команд:

```bash
terraform destroy -no-color | tee logs/04-destroy.txt
```

Подтвердить удаление вводом `yes`. Существующую инфраструктуру вне этого state
Terraform не удаляет. Не удалять state до успешного удаления ресурсов.

State хранится локально (удалённый backend не настроен).
В сдаваемый архив включить .tf, README.md, .gitignore и .terraform.lock.hcl.
Не включать .terraform/, state, планы, terraform.tfvars, токены или приватные
ключи. Отчёт на одну страницу составить по фактическим logs/01-05:
итог plan, apply, повторный No changes, destroy и пустой список ВМ.
Не заменять реальные результаты ожидаемыми строками из этой инструкции.

## Источники

- https://yandex.cloud/ru/docs/terraform/quickstart
- https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs
- https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/vpc_gateway
