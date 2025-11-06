# Nextcloud User Integration Summary

## 🧭 Executive Summary

The Nextcloud User Integration Project transitioned from standalone local authentication to a fully secured LDAP (Active Directory) integration, enabling centralized user management within an air-gapped or hybrid network environment. The progression emphasized security, certificate trust, and proxy compatibility, ensuring compliance with FIPS and DoD enclave standards.

Key outcomes:

* Established **LDAPS-based authentication** with trusted certificates.
* Implemented **attribute and group mapping** to Active Directory.
* Achieved stable **proxy integration** through Traefik and Cloudflare tunnels.
* Retained **local admin fallback** for air-gapped continuity.

---

## ⚙️ Technical Summary

### Environment

* **Nextcloud Stack:** Dockerized on `conman01` (Proxmox VE cluster)
* **Directory Service:** Windows Server AD (`1233lab.local`) with LDAPS (636) and StartTLS
* **Reverse Proxy:** Traefik v3.1 with mkcert CA, Cloudflare tunnels
* **Security Mode:** FIPS-aligned; TLS enforced for all services

---

### Integration Phases

#### 1. Local Bootstrap Phase

* Created local admin accounts for initial configuration and app setup.
* Added trusted domains and proxy settings via environment variables.
* Verified local authentication, password policy, and group permissions.

#### 2. LDAP Discovery & Certificate Validation

* Confirmed LDAPS certificate validity using PowerShell.
* Tested connectivity via `ldapsearch` and PHP scripts.
* Fixed errors due to incorrect Base DN (`dc=1223lab` ➞ `dc=1233lab`).
* Installed trusted CA chain into the Nextcloud container.

#### 3. Secure Binding & Attribute Mapping

* Enabled LDAPS with StartTLS fallback.
* Mapped attributes:

  * UID ➞ `sAMAccountName`
  * Display Name ➞ `cn`
  * Email ➞ `mail`
  * Groups ➞ `memberOf`
* Verified user search via `php occ ldap:search`.

#### 4. Policy and Lifecycle Management

* Aligned password and lockout policies using PowerShell attributes:

  * `PasswordNeverExpires`, `CannotChangePassword`, `LockedOut`.
* Verified that Nextcloud respects AD account states.

#### 5. Reverse Proxy & Cloudflare Integration

* Resolved 404 and redirect loops from mismatched host headers.
* Configured Cloudflare ingress:

  ```yaml
  originRequest:
    httpHostHeader: nextcloud-dev.lan
  ```
* Updated Nextcloud config:

  ```php
  'trusted_proxies' => ['172.16.0.0/12', '10.0.0.0/8'],
  'trusted_domains' => ['nextcloud-dev.lan', 'nextcloud-dev.ppear.net'],
  ```

#### 6. Final Validation

* Tested local and external access via both LDAPS and Cloudflare tunnel.
* Verified group sync, account status, and certificate trust.
* Ensured local admin access for contingency operations.

---

## 🚧 Challenges & Resolutions

| Challenge            | Root Cause                      | Resolution                               |
| -------------------- | ------------------------------- | ---------------------------------------- |
| LDAPS bind failures  | Incorrect Base DN, untrusted CA | Corrected DN; imported AD CA             |
| Connection loss      | Timeout, StartTLS misconfig     | Forced LDAPS 636 with verified URI       |
| Cloudflare 404       | Origin mismatch                 | Adjusted host header and trusted domains |
| Attribute mismatch   | Wrong UID field                 | Aligned to `sAMAccountName`              |
| Password policy sync | Attribute misreads              | Confirmed via PowerShell                 |
| Container CA trust   | Missing CA chain                | Used `update-ca-certificates`            |
| Proxy trust failure  | Incomplete IP range             | Added `10.0.0.0/8`, `172.16.0.0/12`      |

---

## 🏁 Outcome

* **Secure LDAPS authentication** with centralized AD control
* **Local admin fallback** for isolated operations
* **Proxy interoperability** validated for internal and external use
* **Policy synchronization** with Active Directory
* **TLS certificate trust** confirmed under FIPS-mode constraints

**Nextcloud User Integration Task: *Complete***
