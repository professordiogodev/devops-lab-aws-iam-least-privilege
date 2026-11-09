# IAM Users & Least Privilege

An intern, a leaked key and an investor audit. Build least-privilege access, then attack it as the intern.

| | |
|-|-|
| **Time** | 75-90 min |
| **Cost** | free |
| **You need** | An AWS account where you are an administrator, and a private/incognito browser window |

## How this lab works

1. **Fork** this repository to your own GitHub account (button at the top right).
2. Clone **your fork** in your Ubuntu environment (WSL on Windows, your OrbStack machine on Mac).
3. Read the lab below (the same text is in [`LAB.md`](LAB.md)) and follow the mission.
4. Answer the questions in [`SUBMISSION.md`](SUBMISSION.md). Where a question asks for output, paste it in a code block. No screenshots needed.
5. Commit and push. Open the **Actions** tab of your fork (click *I understand my workflows, go ahead and enable them* the first time). The **Lab check** shows what is still missing.
6. When the check is green, **submit the URL of your fork** in the course platform.

> The check only looks at your answers and any files the lab asks you to commit. Your instructor reads your work and may ask you to explain any line.

---

## The situation

It is Monday, 09:10. Clipstr, a four-person URL-shortener startup, has an investor due-diligence call on Friday. The investors' security consultant has already sent a message: *"Everyone at Clipstr logs in with the same AWS account, and the password is on a sticky note. Fix identity before Friday or we pause the deal."*

Then it gets worse. Sam, the new intern, starts today and needs to work on the app. The CTO's instruction: *"Give Sam access to what Sam needs. Not a click more."*

You are the DevOps engineer. You will set up identity properly, then **attack your own work** as Sam to prove it holds.

> **Your mission**
> - Check how healthy the account's identity setup is today
> - Build a group and a **least-privilege** policy for developers
> - Create Sam's user and prove the policy works from Sam's point of view, not just on paper
> - Handle a leaked access key
> - Find the evidence of everything Sam did in the audit log

**Time:** 75-90 min | **Cost:** free (S3 buckets and IAM cost nothing while empty) | **You need:** an AWS account where you are an administrator, and a second browser window (private/incognito)

> Check the **Region** shown at the top right of the console. IAM is global, but the S3 buckets you create will live in the Region you pick. Use the same Region for the whole week.

---

## Part 1 - Recon: how bad is it?

Before changing anything, look at the account like an auditor would.

1. Open the **IAM** service. On the **Dashboard**, find the **Security recommendations** card.
2. Open **Users** and **User groups**. How many exist? Who is the only identity in this account right now?
3. Note the **Account ID** (top right, under your name). Write it down, you will need it.
4. Find **Account alias** on the dashboard (right-hand side). Create an alias such as `clipstr-<your-initials>`. Look at the **sign-in URL** for IAM users that appears. It uses the alias instead of the 12-digit ID.

> **Think**
> - What does the dashboard say about **MFA on the root user** and **root access keys**? Why do these two checks matter more than any other?
> - If you are logged in as an IAM user or SSO role today, why is that already better than using the root user for daily work?

---

## Part 2 - Build: a group, a policy, two buckets

### 2.1 Create something to protect

IAM only matters if there is something worth protecting. Create two S3 buckets (**S3 -> Create bucket**, leave defaults, note **Block all public access** stays on):

| Bucket | Purpose |
|--------|---------|
| `clipstr-uploads-<initials>-<4 digits>` | The bucket developers are allowed to use |
| `clipstr-finance-<initials>-<4 digits>` | Private finance exports, developers must NOT touch these |

Upload any small file to each.

### 2.2 The developer group

Create the user group `Clipstr-Developers` (IAM -> User groups). Do not attach anything yet.

### 2.3 The policy: what does a Clipstr developer need?

Developers need exactly this, and nothing else:

| Need | Details |
|------|---------|
| See servers | List and describe EC2 resources (read-only) |
| Use the uploads bucket | List the bucket; get, put and delete objects in it. **Only that bucket** |
| Read app secrets | Get and describe secrets whose name starts with `clipstr/` |
| Write logs and metrics | Basic CloudWatch Logs and `PutMetricData` |

Create the policy **`ClipstrDeveloperPolicy`** (IAM -> Policies -> Create policy):

1. Start in the **Visual** editor. For each row of the table add a statement: pick the service, pick actions from the lists (use the access-level groups, such as *List* and *Read*, to find them), and set resources. Notice how the visual editor lets you choose **specific ARNs** instead of `*`.
2. Switch to the **JSON** tab and read what the visual editor generated. Each statement has an `Effect`, `Action` and `Resource`.
3. Look at the validation tabs at the bottom of the JSON editor (**Security**, **Errors**, **Warnings**, **Suggestions**). Read whatever it shows.

> **Predict**
> Edit one statement in the JSON editor so `"Resource"` is `"*"` instead of your bucket ARN, but do not save. What do you expect to change in the validation panel? Look, and write down what happened. Then undo your change.

> **Stuck?** Reference policy (replace the bucket name with yours). Compare it with your own. Differences are fine as long as you can explain them:
>
> ```json
> {
>   "Version": "2012-10-17",
>   "Statement": [
>     { "Sid": "SeeServers", "Effect": "Allow", "Action": ["ec2:Describe*"], "Resource": "*" },
>     { "Sid": "OneBucketOnly", "Effect": "Allow",
>       "Action": ["s3:ListBucket", "s3:GetBucketLocation"],
>       "Resource": "arn:aws:s3:::clipstr-uploads-XXXX" },
>     { "Sid": "ObjectsInThatBucket", "Effect": "Allow",
>       "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
>       "Resource": "arn:aws:s3:::clipstr-uploads-XXXX/*" },
>     { "Sid": "ClipstrSecretsOnly", "Effect": "Allow",
>       "Action": ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
>       "Resource": "arn:aws:secretsmanager:*:*:secret:clipstr/*" },
>     { "Sid": "LogsAndMetrics", "Effect": "Allow",
>       "Action": ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "cloudwatch:PutMetricData"],
>       "Resource": "*" }
>   ]
> }
> ```

Save the policy, then attach it to the group (**User groups -> Clipstr-Developers -> Permissions -> Add permissions**).

### 2.4 Meet Sam

Create the user `sam-intern` (IAM -> Users -> Create user):

- Tick **Provide user access to the AWS Management Console** -> **I want to create an IAM user**
- Choose a custom password and untick *Users must create a new password at next sign-in* (to save you time in this lab)
- On the permissions step choose **Add user to group** -> `Clipstr-Developers`
- Add the tags `Project=clipstr` and `Owner=<you>`

> **Checkpoint:** open **Users -> sam-intern -> Permissions**. You should see the policy coming from the **group**, not attached directly. Why is that the recommended pattern?

---

## Part 3 - Prove it: become Sam

A policy that looks right on paper can still be wrong. Test it for real.

1. Open a **private/incognito window**. Go to the **sign-in URL from your account alias** (Part 1). Choose **IAM user** and sign in as `sam-intern`.
2. Run the experiments below. For each one, **predict first** (allowed or denied?), then try. Record the result in a table: *action - prediction - result*.

| # | Try this as Sam |
|---|-----------------|
| 1 | Open **EC2 -> Instances** |
| 2 | Click **Launch instances** and try to launch any instance |
| 3 | Open S3 in the console. What does the bucket list page say? |
| 4 | Open your **uploads** bucket directly by pasting this URL (use your bucket name and Region): `https://s3.console.aws.amazon.com/s3/buckets/clipstr-uploads-XXXX` |
| 5 | Upload a new file to the uploads bucket, then download it |
| 6 | Try to open the **finance** bucket the same way |
| 7 | Open **IAM -> Users** |

> **Break it**
> Read the full red error text in experiment 2 and in experiment 6. They tell you exactly **who** was denied, **which action**, on **which resource** and **why**. Find the sentence that says which kind of policy was missing.

> **Think**
> - Experiment 3: why can Sam use the uploads bucket but not even *list* all buckets? What single action would you have to add to fix the bucket list, and what would that leak?
> - Does making the console "feel nice" ever conflict with least privilege? Where would you draw the line?

Stay signed in as Sam in this window for Part 5.

---

## Part 4 - The leaked key drill

Back in your **admin** window. At 14:05 your phone buzzes: *"GitHub Secret Scanning: an AWS access key was found in a public repository."* Sam pushed `.env` to GitHub.

1. Go to **Users -> sam-intern -> Security credentials -> Access keys -> Create access key**. Pick **Command Line Interface (CLI)**. Read the **alternatives** AWS recommends instead of long-lived keys, and write down two of them. Create the key (you do not need to save the secret).
2. Look at the **Last used** column for the key. What does it say, and what would it show if the key had been abused?
3. Respond like an incident handler: **Deactivate** the key first (do not delete yet). Why deactivate before delete? What can you still do with a deactivated key that you cannot do with a deleted one?
4. Open **Users -> sam-intern -> Last accessed** (the Access Advisor tab). Which services has Sam actually used? What would you do with this list when tightening a policy?
5. Delete the key.

---

## Part 5 - Investigate: what did Sam do?

The investors will ask: *"Can you prove who did what?"* The answer lives in **CloudTrail**.

1. Open **CloudTrail -> Event history**. Set the lookup attribute to **User name** and the value to `sam-intern`.
2. Find these events and open each one to read the JSON record:
   - `ConsoleLogin`
   - the denied `RunInstances`: look for the `errorCode` and `errorMessage` fields
   - Your own `CreateUser` and `CreateAccessKey` events: find the field that says **who** did it and **from which IP**
3. Copy the `eventName`, `errorCode`, `errorMessage` and `userIdentity.userName` of the denied `RunInstances` event for your submission.

> Events can take **5-15 minutes** to appear. If the list is empty, carry on with the next section and come back.

> **Think** CloudTrail Event history only keeps 90 days and only management events. What would you configure to keep logs for a year, and where should they be stored so even an administrator cannot quietly delete them?

---

## Level up (optional)

- **Boss level: require MFA.** Add a statement to the group policy that **denies everything** when `aws:MultiFactorAuthPresent` is `false`. Test with Sam. What breaks when you enable MFA on a user who has not set a device up yet? How would you let people set up MFA while this deny is in force?
- **CLI version.** In *CloudShell* (the `>_` icon in the console top bar) the whole group, policy and user setup is a handful of commands: `aws iam create-group`, `create-policy`, `attach-group-policy`, `create-user`, `add-user-to-group`. Look up the exact arguments with `aws iam create-user help`. In the next lab you will install the CLI yourself.
- **Policy Simulator.** Open the IAM Policy Simulator (search for it, or open `policysim.aws.amazon.com`), select `sam-intern`, and test `ec2:RunInstances`, then `s3:GetObject` on both buckets. Do the results match what you saw as Sam?

<!-- submission:start (generated by labs.py, do not edit) -->
## Submission

Answer the questions in `SUBMISSION.md` in **your fork** (paste output in code blocks where asked), push, then submit the **URL of your fork**.

**Questions to answer**

1. Paste your 7-row table from the "become Sam" part: action, your prediction, what actually happened.
2. Paste the full AccessDenied error Sam got when launching an instance. Which part tells you *why* the action was denied? Rewrite it in your own words.
3. In CloudTrail Event history, find the denied `RunInstances` event. Paste its `eventName`, `errorCode`, `errorMessage` and `userIdentity.userName`.
4. What does `arn:aws:s3:::clipstr-uploads-XXXX/*` mean, and what changes if you replace it with `*`? Name one realistic bad outcome of using `"Resource": "*"` for S3 actions.
5. You found Sam's leaked key at 14:05. List, in order, the first four things you would do and explain why you deactivate before you delete.
<!-- submission:end -->
