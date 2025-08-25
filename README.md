# Lesson-5 Terraform Project

> Інфраструктура на AWS за допомогою Terraform: **ECR** репозиторій, **VPC** (публічні/приватні підмережі) і **S3 backend** для state з блокуванням у **DynamoDB**.

---

## Зміст

- [Lesson-5 Terraform Project](#lesson-5-terraform-project)
  - [Зміст](#зміст)
  - [Огляд](#огляд)
  - [Структура проєкту](#структура-проєкту)
  - [Попередні вимоги](#попередні-вимоги)
  - [Налаштування backend (S3 + DynamoDB)](#налаштування-backend-s3--dynamodb)
    - [Варіант A — Bootstrap (рекомендовано)](#варіант-a--bootstrap-рекомендовано)
    - [Варіант B — Import існуючих ресурсів](#варіант-b--import-існуючих-ресурсів)
  - [Змінні](#змінні)
    - [Глобальні](#глобальні)
    - [Модуль **ecr**](#модуль-ecr)
    - [Модуль **s3-backend**](#модуль-s3-backend)
    - [Модуль **vpc**](#модуль-vpc)
  - [Швидкий старт](#швидкий-старт)
  - [Робота з ECR](#робота-з-ecr)
  - [Виводи (Outputs)](#виводи-outputs)
  - [Типові помилки та рішення](#типові-помилки-та-рішення)
  - [Нотатки з безпеки та бест‑практик](#нотатки-з-безпеки-та-бестпрактик)
    - [Ліцензія](#ліцензія)

---

## Огляд

Проєкт створює:

- **Amazon ECR** репозиторій із ввімкненим **scan on push** та політикою доступу (in‑account push/pull; опційно — cross‑account pull).
- **VPC** із CIDR `10.0.0.0/16`, трьома **public** та трьома **private** підмережами в **us-east-1a/b/c**, Internet Gateway, маршрути.
- **S3 backend** для зберігання Terraform state та **DynamoDB** таблицю для блокування state.

> ⚠️ Важливо: регіон у прикладах — **us-east-1**. Узгодьте його всюди (backend, модулі, CLI).

---

## Структура проєкту

```
.
├── main.tf
├── backend.tf                # terraform { backend "s3" { ... } }
├── outputs.tf
├── modules/
│   ├── ecr/
│   │   ├── ecr.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── s3-backend/
|   |   ├── dynamodb.tf
│   │   ├── variables.tf
│   │   ├── s3.tf
│   │   └── outputs.tf
│   └── vpc/
|.      ├── routes.tf
│       ├── vpc.tf
│       ├── variables.tf
│       └── outputs.tf
└── README.md (цей файл)
```

---

## Попередні вимоги

- **Terraform** ≥ 1.5
- **AWS CLI** ≥ 2.x
- Налаштований доступ до AWS:

  - **SSO**: `aws configure sso` → `aws sso login --profile <profile>`
  - **Access keys**: `aws configure`

- Дозволи на створення ресурсів S3, DynamoDB, ECR, VPC.

---

## Налаштування backend (S3 + DynamoDB)

Бекенд визначений у `backend.tf` як `backend "s3"`. Потрібні ресурси:

- **S3 bucket**: наприклад, `eduard-schumacher-tf-bucket` у **us-east-1**
- **DynamoDB table**: `terraform-locks` (Partition key: `LockID` типу **S**) у **us-east-1**

> Якщо ресурси вже існують — не створюйте їх вдруге тим самим стеком. Оберіть import або вимкніть модуль створення backend.

### Варіант A — Bootstrap (рекомендовано)

1. Тимчасово використайте **local** backend (закоментуйте блок `backend "s3"` у корені).
2. `terraform init -reconfigure`
3. Створіть лише бекенд‑ресурси:

   ```bash
   terraform apply -target=module.s3_backend
   ```

4. Поверніть блок `backend "s3"` і виконайте міграцію state:

   ```bash
   terraform init -migrate-state
   ```

### Варіант B — Import існуючих ресурсів

Якщо бакет і таблиця вже створені, імпортуйте їх у state:

```bash
terraform import module.s3_backend.aws_dynamodb_table.terraform_locks terraform-locks
terraform import module.s3_backend.aws_s3_bucket.terraform_state eduard-schumacher-tf-bucket
terraform import module.s3_backend.aws_s3_bucket_ownership_controls.terraform_state_ownership eduard-schumacher-tf-bucket
terraform import module.s3_backend.aws_s3_bucket_versioning.terraform_state_versioning eduard-schumacher-tf-bucket
```

> Порада: у модулі `s3-backend` зручно мати прапорець `manage_backend` (true/false) і обгортати ресурси через `count`, щоб легко відключати їх створення.

---

## Змінні

### Глобальні

Використовуються змінні для ECR (див. нижче). Для S3/VPC зазвичай налаштовуються в їхніх модулях.

### Модуль **ecr**

| Змінна                 | Тип           | Значення за замовчуванням | Опис                                                                |
| ---------------------- | ------------- | ------------------------- | ------------------------------------------------------------------- |
| `repository_name`      | string        | — (обов’язково)           | Ім’я ECR репозиторію (напр., `lesson-5-ecr`).                       |
| `image_tag_mutability` | string        | `MUTABLE`                 | `MUTABLE` або `IMMUTABLE`.                                          |
| `image_scan_on_push`   | bool          | `true`                    | Ввімкнути сканування образів на push.                               |
| `force_delete`         | bool          | `true`                    | Видаляти репозиторій, навіть якщо в ньому є образи (для `destroy`). |
| `allowed_principals`   | list(string)  | `[]`                      | (Опційно) ARN-и для cross‑account pull.                             |
| `repository_policy`    | string (JSON) | `null`                    | (Опційно) повний JSON policy, який перекриває згенеровану політику. |
| `tags`                 | map(string)   | `{}`                      | Додаткові теги.                                                     |

### Модуль **s3-backend**

Ресурси S3/DynamoDB для бекенда. Якщо використовуєте import/зовнішні ресурси — вимкніть їх створення через прапорець (якщо реалізований) або приберіть модуль із кореня.

Основні ресурси:

- `aws_s3_bucket.terraform_state`
- `aws_dynamodb_table.terraform_locks (LockID: S)`
- `aws_s3_bucket_versioning` (Enabled)
- `aws_s3_bucket_ownership_controls` (BucketOwnerEnforced)

### Модуль **vpc**

- **CIDR**: `10.0.0.0/16`
- **Public subnets**: `10.0.1.0/24`, `10.0.2.0/24`, `10.0.3.0/24` у AZ `us-east-1a/b/c`
- **Private subnets**: `10.0.4.0/24`, `10.0.5.0/24`, `10.0.6.0/24` у AZ `us-east-1a/b/c`

> Рекомендація: генеруйте список AZ через `data "aws_availability_zones"` і використовуйте `local.azs[0..2]`, щоб уникати змішування регіонів.

---

## Швидкий старт

1. **Аутентифікація в AWS**

   ```bash
   # SSO
   aws configure sso
   aws sso login --profile my-aws-profile
   export AWS_PROFILE=my-aws-profile

   # або Access Keys
   export AWS_ACCESS_KEY_ID=...
   export AWS_SECRET_ACCESS_KEY=...
   export AWS_REGION=us-east-1
   ```

2. **Ініціалізація**

   ```bash
   terraform init -reconfigure
   ```

3. **Валідація і план**

   ```bash
   terraform validate
   terraform plan
   ```

4. **Застосування**

   ```bash
   terraform apply
   ```

---

## Робота з ECR

Після `apply` отримаєте `ecr_repository_url` (output). Приклад push образу:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=us-east-1
REPO=lesson-5-ecr
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO"

aws ecr get-login-password --region $REGION \
 | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

docker build -t $REPO:latest .
docker tag $REPO:latest $ECR_URI:latest

docker push $ECR_URI:latest
```

> Для cross‑account pull додайте ARN-и у `allowed_principals` або надайте права через IAM ролі/політики в інших акаунтах.

---

## Виводи (Outputs)

Залежно від модулів/реалізації ви побачите:

- `ecr_repository_url` — повний URI ECR репозиторію
- `vpc_id` — ідентифікатор VPC
- `public_subnets[]`, `private_subnets[]` — списки сабнетів
- `s3_bucket_name`, `s3_bucket_url` — бекенд бакет

---

## Типові помилки та рішення

- **Extra characters after interpolation expression**

  - Причина: синтаксис `${aws:s3_bucket...}` або зайві двокрапки.
  - Рішення: `aws_s3_bucket.resource_name.attribute` і правильні назви атрибутів (`bucket_regional_domain_name`).

- **Invalid multi-line string / Unterminated template string**

  - Причина: незакрита лапка `"` у рядку.
  - Рішення: закрийте лапки, не розбивайте рядок.

- **No valid credential sources found**

  - Причина: немає AWS креденшлів (CLI профіль/SSO/keys).
  - Рішення: налаштуйте `AWS_PROFILE` або ключі, виконайте `aws sso login`.

- **Error acquiring the state lock (ResourceNotFoundException)**

  - Причина: таблиця `terraform-locks` відсутня або в іншому регіоні.
  - Рішення: створіть таблицю `LockID (S)` у регіоні бекенда.

- **301, requested bucket from "X", actual location "Y"**

  - Причина: регіон бакета відрізняється від вказаного в backend.
  - Рішення: вирівняйте `region` у `backend "s3"` з фактичним регіоном бакета.

- **Deprecated Parameter: dynamodb_table**

  - Причина: параметр опинився поза блоком `backend "s3"`.
  - Рішення: перемістіть `dynamodb_table` всередину `backend "s3"`. Не плутайте з `use_lockfile`.

- **Unsupported attribute: bucket_region_domain_name**

  - Причина: опечатка; правильний атрибут — `bucket_regional_domain_name`.

- **AZ не з того регіону**

  - Причина: використані `us-east-2b/c` при регіоні `us-east-1`.
  - Рішення: замінити на `us-east-1b/c` або генерувати AZ динамічно.

---

## Нотатки з безпеки та бест‑практик

- **ECR tag immutability**: якщо процес релізів дозволяє — встановіть `image_tag_mutability = "IMMUTABLE"`.
- **Lifecycle policy** для ECR: приберіть untagged образи через `aws_ecr_lifecycle_policy`.
- **KMS шифрування**: якщо потрібно BYOK — задайте KMS ключ для ECR/S3.
- **Least privilege**: крос‑акаунтний доступ через чіткі ARN у `allowed_principals` або через роль AssumeRole.
- **State захист**: не вимикайте лок (`-lock=false`), окрім аварійних випадків.

---

### Ліцензія

Вкажіть вашу ліцензію тут (за потреби).
