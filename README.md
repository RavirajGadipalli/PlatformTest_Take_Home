# Platform Engineering Test

## Overview

You are a **Senior Platform Engineer** reviewing code written by a junior engineer on your team. The project includes a .NET application, Terraform infrastructure, a CI/CD pipeline, and monitoring configuration.

The junior engineer has gotten everything "working" but has made mistakes across security, infrastructure design, deployment safety, and operational best practices. Your job is to:

1. **Review the application code** — identify security vulnerabilities and production risks, write up your findings as a code review, and implement at least one security fix
2. **Review and fix** the infrastructure components (Terraform, Pipeline, Monitoring)
3. **Add comments** explaining *why* you're making changes — as if teaching the junior engineer

You do NOT need to refactor everything or rewrite the application from scratch. We want to see that you can identify what's wrong, prioritize what matters, explain the impact, and demonstrate you know how to fix it. If you see additional things you'd improve given more time, call them out in your write-up.

---

## Time Expectation

This test is designed to take **2-3 hours**. You do not need to make everything production-perfect - prioritize the most impactful changes and explain what you'd do with more time.

---

## What's Included

```
PlatformTest/
+-- README.md                          (this file)
+-- PlatformTest.sln                   (Solution file)
+-- PlatformTest.csproj                (.NET Framework 4.8 console app)
+-- Program.cs                         (Application code - Book Reading Service)
+-- App.config
+-- packages.config
+-- LanguagePrices_Unencrypted.xml     (XML data file with pricing)
+-- Properties/
|   +-- AssemblyInfo.cs
+-- terraform/
|   +-- main.tf                        (Azure Container App infrastructure)
|   +-- variables.tf                   (Input variables)
|   +-- outputs.tf                     (Outputs)
|   +-- configuration/
|       +-- nonprod.tfvars             (Nonprod environment variables)
|       +-- prod.tfvars                (Production environment variables)
+-- pipeline/
|   +-- azure-pipelines.yml            (CI/CD pipeline for the Container App)
+-- monitoring/
    +-- datadog-monitors.tf            (Datadog monitoring configuration)
```

---

## Component Details

### 1. Application Code (`Program.cs`)

A .NET Framework 4.8 console application — the "Book Reading Service" — that searches the OpenLibrary API and calculates reading costs based on language and page count.

**What We Expect:**
1. Write a code review identifying the security vulnerabilities and production risks you find. For each issue, explain the impact and how you'd fix it — as if you're teaching the junior engineer.
2. Implement **at least one security fix** in the code to demonstrate your approach.

You do NOT need to refactor the entire application or rewrite it. Focus on what you'd flag in a real code review and show that you can fix the most critical issues.

---

### 2. Terraform - Azure Container App Infrastructure (`terraform/`)

A Terraform configuration for deploying an Azure Container App with supporting resources. The pipeline uses environment-specific `.tfvars` files (`nonprod.tfvars`, `prod.tfvars`) to deploy to each environment.

Review and fix the issues you find. Add comments explaining your changes.

---

### 3. CI/CD Pipeline (`pipeline/`)

An Azure DevOps YAML pipeline for building a container image and deploying infrastructure via Terraform to nonprod and production environments.

Review and fix the issues you find. Add comments explaining your changes.

---

### 4. Observability (`monitoring/`)

Datadog monitor configurations for an application.

Review and fix the issues you find. Add comments explaining your changes.

---

## Evaluation Criteria

We're evaluating your ability to:

| Area | What We're Looking For |
|------|----------------------|
| **Security Awareness** | Can you identify and fix security issues across application code and infrastructure? |
| **Infrastructure Design** | Do you understand Terraform patterns and cloud architecture best practices? |
| **CI/CD Expertise** | Can you design safe, efficient deployment pipelines? |
| **Observability** | Do you understand what to monitor and how to alert effectively? |
| **Communication** | Can you explain *why* changes matter in a way that teaches others? |
| **Prioritization** | Do you focus on high-impact issues vs. cosmetic ones? |

---

## Submission

- Submit your work as a **zip file** or **GitHub repository link**
- Include a brief `CHANGES.md` at the root summarizing your findings, fixes, and anything you'd do with more time
- Be prepared to walk through and discuss your changes in a follow-up interview

---

## Notes

- You do NOT need to run or apply any of this code — focus on the review and fixes
- If a fix requires an external tool or service you don't have access to (e.g., Azure Key Vault, Datadog API), stub it out with comments explaining your approach
- Use whatever tools are available to you (AI assistants, documentation, etc.) — we care about your judgment and communication, not memorization
- There is no single "right answer" — we want to see how you think about platform engineering problems
- Be prepared to discuss your changes in detail during the follow-up interview

Good luck!
