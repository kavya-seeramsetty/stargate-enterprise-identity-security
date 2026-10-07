\# StarGate Technologies: Enterprise Identity, Access Management \& Windows Security



StarGate Technologies is a hands-on enterprise IT and security project that I built from scratch to practice how identity, access, Windows security, and day-to-day IT operations work together in a real organization.



For this project, I created a simulated 100-user company with employees across US and European locations. I built the Windows domain, organized users and computers, created security groups, configured administrative permissions, applied Group Policy security settings, investigated Windows security events, created incident response procedures, and built PowerShell automation for common administrative tasks.



The main goal was not just to configure everything and take screenshots. I wanted to understand what happens when something goes wrong, how to investigate it, how to validate a fix, and how some of the repetitive work could be automated.



> \*\*Environment:\*\* Simulated enterprise environment  

> \*\*Domain:\*\* `stargate.local`  

> \*\*Users:\*\* Approximately 100  

> \*\*Sites:\*\* US and Europe  

> \*\*Focus:\*\* Identity, access management, Windows security, incident response, and PowerShell automation



\---



\# What I Built



The project covers the main areas I wanted to practice for an enterprise infrastructure and security environment.



\- Active Directory domain

\- Organizational Unit structure

\- User and computer management

\- Security groups

\- Administrative account separation

\- Delegated administration

\- Helpdesk permissions

\- Password and account lockout policies

\- Group Policy security controls

\- Workstation security

\- Windows Security event investigation

\- Authentication monitoring

\- Privileged activity monitoring

\- Incident response

\- PowerShell automation

\- Security and configuration validation



\---



\# Architecture



!\[StarGate Architecture](architecture/01-StarGate-Architecture-Diagram.png)



The StarGate environment is built around a Windows domain.



\## Main Systems



| System | Purpose |

|---|---|

| DC01 | Windows Server 2022 Domain Controller |

| CLIENT01 | Standard employee workstation |

| CLIENT02 | Administrative and helpdesk workstation |



\## Domain



\*\*Domain:\*\* `stargate.local`



DC01 provides:



\- Active Directory Domain Services

\- Domain Name System (DNS)

\- Global Catalog

\- User authentication

\- Group Policy processing

\- User and computer management



CLIENT01 represents a normal employee workstation.



CLIENT02 is used for administrative tasks and testing delegated permissions. I intentionally separated the administrative workstation from the normal employee workstation so that privileged activity could be tested in a more realistic way.



\---



\# Active Directory Structure



!\[StarGate OU Structure](architecture/02-StarGate-OU-Structure.png)



I created an Organizational Unit structure to keep the environment organized and make it possible to apply different policies to different groups of users and computers.



\## User Departments



\- Engineering

\- Operations

\- Information Technology

\- Sales

\- Finance

\- Human Resources

\- Management

\- Marketing



\## Computer Organization



\- Workstations

\- Servers

\- Quarantine



\## Administrative Organization



\- Helpdesk

\- Information Technology Administrators

\- Privileged Users

\- Service Accounts



The environment contains approximately 100 employee accounts distributed across the department structure.



\---



\# Identity and Access Management



A major part of the project was figuring out how to give administrators enough access to do their jobs without giving everyone full domain administrator privileges.



I created separate administrative roles for different responsibilities.



These include:



\- Helpdesk administration

\- Identity administration

\- Group administration

\- Computer administration

\- Infrastructure administration

\- Network administration

\- Domain administration



The idea was to follow the principle of least privilege.



An administrator should have the permissions needed for their role, but should not automatically have access to everything in the environment.



\## Helpdesk Testing



I tested the Helpdesk role using a normal employee account.



The Helpdesk administrator was able to:



1\. Locate the employee account

2\. Reset the employee password

3\. Allow the employee to sign in with the new password



I then tested an action outside the Helpdesk role.



The Helpdesk administrator was not allowed to create users.



This was important because it showed that the permission boundary was actually working.



\---



\# Delegated Administration



I did not want to assume that the delegation configuration was correct just because the permissions appeared in Active Directory.



I tested the different administrative roles against actual objects.



\### Helpdesk Administrator



Tested:



\- Password reset

\- Employee account recovery

\- Permission boundaries



\### Group Administrator



Tested:



\- Modifying membership of the Engineering security group



\### Computer Administrator



Tested:



\- Access to the CLIENT01 computer object

\- Modifying the computer description



One useful lesson here was that Active Directory delegation depends heavily on where objects actually exist.



For example, my initial Group Administrator delegation did not work as expected because the security groups were located in the built-in Users container rather than the Organizational Unit where I had initially applied the delegation.



After identifying the actual location of the groups, I corrected the delegation and tested it again successfully.



\---



\# Group Policy Security



Group Policy was used to apply centralized security settings to the Windows environment.



The configuration includes:



\- Password requirements

\- Account lockout settings

\- Screen saver settings

\- Automatic workstation locking

\- Password protection after screen lock

\- User restrictions

\- Windows Firewall related settings

\- User Account Control settings

\- Guest account restrictions

\- Security auditing



\## Screen Lock Troubleshooting



The screen lock configuration was one of the areas where I had to troubleshoot an actual problem.



I initially configured:



\- Enable screen saver

\- Screen saver timeout

\- Password protection



The settings appeared to be configured correctly, but the expected screen locking behavior was not happening on CLIENT01.



I checked the applied Group Policy results and investigated the configuration rather than assuming the policy was broken.



The issue was resolved by enabling the setting that forces a specific screen saver.



After that change, CLIENT01 successfully locked after 60 seconds.



This became a useful lesson for the project because it showed the difference between configuring a policy and actually proving that the policy works on an endpoint.



\---



\# Security Monitoring



I used Windows Security logs to investigate authentication and administrative activity.



Some of the main Windows Security events I worked with were:



| Event ID | Activity |

|---|---|

| 4624 | Successful logon |

| 4625 | Failed logon |

| 4672 | Special privileges assigned to a new logon |

| 4720 | User account created |

| 4723 | User attempted to change a password |

| 4724 | Password reset |

| 4725 | User account disabled |

| 4726 | User account deleted |

| 4728 | Member added to a security enabled global group |

| 4732 | Member added to a security enabled local group |

| 4740 | User account locked out |

| 4648 | Logon attempted using explicit credentials |



I created test activity and then investigated the resulting events.



For example, I generated failed authentication events and account lockout activity and used the Windows Security log to identify what happened.



This helped me move beyond simply knowing event numbers and practice using them during an investigation.



\---



\# Incident Response



I created incident response procedures for several common Windows and identity related problems.



Completed scenarios include:



\- Account lockout

\- Unexpected access

\- Group Policy failure

\- Domain join failure

\- Authentication failure



The general investigation process I used was:



\*\*Identify → Investigate → Validate → Assess Impact → Remediate → Verify → Document\*\*



I also learned to distinguish between something that looks unusual and something that is actually broken.



For example, a warning or unexpected result does not automatically mean that there is a security incident. It needs to be investigated and its impact understood before deciding whether remediation is necessary.



\---



\# PowerShell Automation



I used PowerShell to automate repetitive identity and security tasks.



The scripts were designed to do more than simply execute an Active Directory command.



Where appropriate, they validate input, check permissions, confirm actions, verify results, and create reports.



\## Account Lockout Investigation



\*\*Script:\*\* `powershell/Manage-AccountLockout.ps1`



This script helps investigate and handle locked accounts.



It can:



\- Identify the current administrator

\- Check whether the administrator is authorized

\- Find locked user accounts

\- Display account information

\- Ask for confirmation before unlocking an account

\- Unlock the selected account

\- Verify the account is no longer locked

\- Record the action in an audit log



I tested this by deliberately locking an employee account and then using the script to investigate and unlock it.



\---



\## Employee Offboarding



\*\*Script:\*\* `powershell/Disable-Employee.ps1`



This script automates several steps that could be part of an employee offboarding process.



It can:



\- Disable the employee account

\- Remove the employee from the department security group

\- Move the account to the Disabled Users Organizational Unit

\- Verify the account state

\- Generate an offboarding report



I tested the process with a test employee account and verified the resulting account state.



\---



\## Failed Login Investigation



\*\*Script:\*\* `powershell/Get-RecentFailedLogins.ps1`



This script investigates Windows Event ID 4625.



It extracts information including:



\- Username

\- Timestamp

\- Source IP address

\- Source port

\- Workstation

\- Logon type

\- Authentication package

\- Failure reason

\- Status

\- Substatus

\- Event ID



The script can produce both detailed results and a report that can be used during an investigation.



\---



\## Privileged Group Audit



\*\*Script:\*\* `powershell/Audit-PrivilegedGroups.ps1`



This script checks membership of the privileged security groups used in the StarGate environment.



It compares the current membership against the expected administrative roles and reports unexpected memberships.



An important part of the design is that the script does not automatically remove unexpected members.



An unexpected account should be investigated first. Automatically removing it could cause an operational problem if the membership is legitimate.



The audit therefore produces a finding for review instead of assuming that every unexpected result is malicious.



\---



\## Employee Provisioning



\*\*Script:\*\* `powershell/New-Employee.ps1`



This script automates the creation of a new employee account.



The process validates:



\- Employee ID

\- Name

\- Department

\- Job title

\- Manager

\- Office location

\- Start date

\- Target Organizational Unit

\- Department security group

\- Duplicate usernames



After confirmation, the script:



1\. Creates the Active Directory account

2\. Adds the employee to the appropriate department group

3\. Configures the initial password

4\. Requires a password change at first login

5\. Verifies the account

6\. Generates an onboarding report



I tested the provisioning process with a new employee and verified that the account and group membership were created correctly.



\---



\# Inactive Account Audit



\*\*Script:\*\* `powershell/Get-InactiveUsers.ps1`



This script is included in the repository as part of the automation work, but I am not presenting it as a completed production control.



During the project, I identified that using password age alone is not a reliable way to determine whether an account is actually inactive.



The approach needs to be redesigned around meaningful account activity data.



I kept the script in the repository as a development artifact rather than pretending that the implementation was complete.



\---



\# Automation Validation



I tested the automation with several goals in mind.



\### Normal execution



The scripts were tested with valid inputs and expected scenarios.



\### Invalid input



Inputs such as invalid usernames, invalid department selections, duplicate accounts, and other incorrect values were tested where applicable.



\### Error handling



The scripts were designed to provide useful errors instead of silently failing.



\### Verification



Where the script changes an Active Directory object, the resulting state is checked afterward where appropriate.



\### Reporting



Several scripts create text or CSV reports so that the result of an operation can be reviewed later.



\### Security



Passwords are not written to reports, and sensitive operations require controlled execution and confirmation where appropriate.



\---



\# Evidence



The `evidence/` directory contains screenshots showing selected implementation and validation work.



The evidence includes:



\- Domain health validation

\- DNS validation

\- Active Directory users

\- Active Directory security groups

\- Group Policy configuration

\- Applied Group Policy results

\- Screen lock validation

\- Group Policy troubleshooting

\- Helpdesk password reset

\- Helpdesk permission testing

\- Group Administrator testing

\- Computer Administrator testing

\- Failed authentication events

\- Account lockout events

\- User creation events

\- Privileged logon events

\- Group membership changes



The evidence is there to support the implementation.



The repository is not intended to be a collection of screenshots without context.



\---



\# What I Learned



This project gave me a better understanding of how different parts of Windows enterprise administration fit together.



\## Configuration is not validation



A setting can look correct in a management console and still not behave as expected on a workstation.



Testing the actual endpoint matters.



\## Least privilege needs to be tested



Creating an administrative group does not prove that the permissions are correct.



The important part is testing what that administrator can and cannot actually do.



\## Object location matters



Active Directory permissions depend on where objects are located.



The Group Administrator issue taught me that I need to check the actual location of an object before deciding where delegation should be applied.



\## Unexpected does not automatically mean malicious



An unexpected group member or security event should be investigated before making assumptions.



\## Automation should verify its work



A script that changes an account should ideally verify the result.



This makes the automation more useful for real operational work.



\## Troubleshooting is part of the implementation



The screen lock problem was not something I wanted to hide.



Finding the problem, testing possible causes, applying the fix, and verifying the result was one of the more useful parts of the project.



\---



\# Future Improvements



There are several areas I would expand if I continued developing StarGate.



\## Multiple Domain Controllers



The current environment uses one Domain Controller.



A larger version of the environment would add additional Domain Controllers and separate sites so that I could properly test:



\- Active Directory replication

\- DNS redundancy

\- Site configuration

\- Inter-site replication

\- Domain Controller failover

\- Replication health



\## Security Information and Event Management



Wazuh is planned as a future enhancement.



It was \*\*not deployed as part of the completed project\*\*, so I have not represented it as a completed implementation.



A future version could add centralized security log collection, alerting, detection rules, dashboards, and endpoint monitoring.



\## Additional Infrastructure



Future versions could also include:



\- Additional Windows servers

\- File services

\- Backup infrastructure

\- Network infrastructure

\- More realistic US and Europe site connectivity

\- Additional endpoint security controls



\---



\# Technology Used



\- Windows Server 2022

\- Active Directory Domain Services

\- Domain Name System (DNS)

\- Group Policy

\- Windows Security Event Logs

\- PowerShell

\- Oracle VirtualBox

\- Active Directory Users and Computers

\- `dcdiag`

\- `repadmin`

\- Windows Event Viewer

\- GitHub



\---



\# Repository Structure



```text

stargate-enterprise-identity-security/

│

├── architecture/

│   ├── 01-StarGate-Architecture-Diagram.png

│   └── 02-StarGate-OU-Structure.png

│

├── documentation/

│

├── evidence/

│   ├── Active Directory evidence

│   ├── Group Policy evidence

│   ├── Delegation evidence

│   └── Security monitoring evidence

│

├── incidents/

│

├── powershell/

│   ├── Audit-PrivilegedGroups.ps1

│   ├── Disable-Employee.ps1

│   ├── Get-InactiveUsers.ps1

│   ├── Get-RecentFailedLogins.ps1

│   ├── Manage-AccountLockout.ps1

│   └── New-Employee.ps1

│

└── README.md

```



\---



\# Final Project Summary



StarGate started as an idea to build a realistic Windows enterprise environment.



It grew into a project covering identity management, access control, security configuration, troubleshooting, monitoring, incident response, and automation.



The overall workflow became:



\*\*Design → Build → Secure → Test → Investigate → Automate → Validate\*\*



The most important part for me was the hands-on work.



I did not want the project to only show that I knew the names of Active Directory features or security concepts. I wanted to configure them, test them, break things where appropriate, troubleshoot them, and understand why the final configuration worked.



StarGate is still a lab environment and has clear areas for future improvement, but it gave me practical experience across several areas of Windows infrastructure and security.



\---



\## Disclaimer



StarGate Technologies is a fictional organization created for educational and portfolio purposes.



No real company infrastructure, credentials, customer information, or production systems are represented in this repository.

