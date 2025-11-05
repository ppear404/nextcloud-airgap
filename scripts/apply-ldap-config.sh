#!/bin/bash

# This script configures LDAP settings for the application.
# It sets the LDAP server URL, base DN, and bind credentials.

# Version: 1.0
# Author: ppear
# Date: 2025-11-04

# https://docs.nextcloud.com/server/stable/admin_manual/occ_command.html#ldap-commands-label
# Example usage:
# php occ ldap:show-config "1" "ldapBase" "dc=example,dc=com"
# php occ ldap:set-config "1" "ldapHost" "ldap.example.com"
# php occ ldap:delete-config "1" "ldapBindPassword"

# Nextcloud application container name
NEXTCLOUD_APP_CONTAINER="nextcloud-app"
# Configuration is the Nextcloud LDAP configuration identifier referenced by occ commands (e.g., s01).
# Copy this script to create an appropriate configuration for your LDAP setup. (e.g s01,s02,...)
Configuration=s01
# hasMemberOfFilterSupport enables use of the LDAP memberOf attribute for group membership checks (0 or 1).
hasMemberOfFilterSupport=1          
# homeFolderNamingRule defines the LDAP attribute or pattern to generate user home folder names (leave empty for default).
homeFolderNamingRule=
# lastJpegPhotoLookup stores the last avatar synchronization timestamp; leave 0 for automatic management.
lastJpegPhotoLookup=0
# ldapAdminGroup names the LDAP group that represents administrators (set to its distinguished name when used).
ldapAdminGroup=
# ldapAgentName is the distinguished name of the bind account used for LDAP queries.
ldapAgentName="CN=ldap bind,OU=admins,OU=1233-dev,DC=1233lab,DC=local"
# ldapAgentPassword is the password for the bind account; store securely if populated.
ldapAgentPassword="simple123P@ss"
# ldapAttributeAddress specifies the LDAP attribute that holds postal address information.
ldapAttributeAddress=
# ldapAttributeAnniversaryDate points to the LDAP attribute containing anniversary dates (e.g., oCAnniversary).
ldapAttributeAnniversaryDate=
# ldapAttributeBiography contains the LDAP attribute used for biography text.
ldapAttributeBiography=
# ldapAttributeBirthDate defines the LDAP attribute that stores user birth dates.
ldapAttributeBirthDate=
# ldapAttributeFediverse is the LDAP attribute exposing a user’s Fediverse handle.
ldapAttributeFediverse=
# ldapAttributeHeadline identifies the LDAP attribute carrying a short headline or tagline.
ldapAttributeHeadline=
# ldapAttributeOrganisation sets which LDAP attribute stores the organization or company name.
ldapAttributeOrganisation="description"
# ldapAttributePhone holds the LDAP attribute used for telephone numbers.
ldapAttributePhone="telephoneNumber"
# ldapAttributePronouns is the LDAP attribute containing a user’s preferred pronouns.
ldapAttributePronouns=
# ldapAttributeRole references the LDAP attribute representing job role or title.
ldapAttributeRole="title"
# ldapAttributeTwitter is the LDAP attribute containing a Twitter/X handle.
ldapAttributeTwitter=
# ldapAttributeWebsite identifies the LDAP attribute pointing to a user’s website URL.
ldapAttributeWebsite=
# ldapAttributesForGroupSearch lists additional attributes searched when resolving LDAP groups.
ldapAttributesForGroupSearch=
# ldapAttributesForUserSearch lists additional attributes searched when resolving LDAP users.
ldapAttributesForUserSearch=
# ldapBackgroundHost is the LDAP host used for background jobs (set to hostname or URI if different).
ldapBackgroundHost=
# ldapBackgroundPort specifies the port for the background LDAP host (usually 389 or 636).
ldapBackgroundPort=
# ldapBackupHost is the fallback LDAP server hostname or URI.
ldapBackupHost=
# ldapBackupPort configures the port for the backup LDAP server.
ldapBackupPort=
# ldapBase defines the base distinguished name for LDAP queries (e.g., dc=example,dc=com).
ldapBase="DC=1233lab,DC=local"
# ldapBaseGroups narrows group searches to a specific organizational unit DN.
ldapBaseGroups="OU=1233_Groups,OU=1233-dev,DC=1233lab,DC=local"
# ldapBaseUsers narrows user searches to a specific organizational unit DN.
ldapBaseUsers="OU=general_users,OU=1233-dev,DC=1233lab,DC=local"
# ldapCacheTTL sets the LDAP cache time-to-live in seconds.
ldapCacheTTL=600
# ldapConfigurationActive toggles whether this LDAP configuration is active (0 disabled, 1 enabled).
ldapConfigurationActive=0
# ldapConnectionTimeout sets the timeout in seconds when connecting to the LDAP server.
ldapConnectionTimeout=15
# ldapDefaultPPolicyDN holds the DN of the default password policy (ppolicy) object if used.
ldapDefaultPPolicyDN=
# ldapDynamicGroupMemberURL defines the attribute for dynamic group member URLs.
ldapDynamicGroupMemberURL=
# ldapEmailAttribute specifies which LDAP attribute contains user email addresses.
ldapEmailAttribute="mail"
# ldapExperiencedAdmin marks that the administrator is experienced with LDAP to unlock advanced settings (0 or 1).
ldapExperiencedAdmin=0
# ldapExpertUUIDGroupAttr overrides the attribute used as the unique identifier for groups.
ldapExpertUUIDGroupAttr=
# ldapExpertUUIDUserAttr overrides the attribute used as the unique identifier for users.
ldapExpertUUIDUserAttr=
# ldapExpertUsernameAttr overrides the LDAP attribute used for Nextcloud usernames.
ldapExpertUsernameAttr=
# ldapExtStorageHomeAttribute sets the LDAP attribute that points to an external storage home directory.
ldapExtStorageHomeAttribute=
# ldapGidNumber selects the LDAP attribute that provides a numeric group identifier.
ldapGidNumber=gidnumber
# ldapGroupDisplayName chooses the attribute shown as the group display name.
ldapGroupDisplayName=cn
# ldapGroupFilter sets the LDAP filter restricting which groups are visible.
ldapGroupFilter=
# ldapGroupFilterGroups lists specific DNs for groups explicitly included.
ldapGroupFilterGroups=
# ldapGroupFilterMode controls how the group filter is applied (0 for whitelist, 1 for exclusive).
ldapGroupFilterMode=0
# ldapGroupFilterObjectclass limits groups to the specified object classes.
ldapGroupFilterObjectclass=
# ldapGroupMemberAssocAttr defines the attribute that lists group member DNs.
ldapGroupMemberAssocAttr=
# ldapHost is the primary LDAP server URI (e.g., ldap://host or ldaps://host).
ldapHost="dc1.1233lab.local"
# ldapIgnoreNamingRules allows bypassing Nextcloud naming restrictions for users and groups (0 or 1).
ldapIgnoreNamingRules=
# ldapLoginFilter specifies the LDAP filter template used when users log in.
ldapLoginFilter="(&(objectClass=user)(objectCategory=person)(|(sAMAccountName=%uid)(userPrincipalName=%uid)))"
# ldapLoginFilterAttributes enumerates LDAP attributes searched during login attempts.
ldapLoginFilterAttributes=
# ldapLoginFilterEmail toggles whether the email attribute is evaluated during login (0 or 1).
ldapLoginFilterEmail=1
# ldapLoginFilterMode controls how the login filter is applied (0 for standard, 1 or 2 for advanced modes).
ldapLoginFilterMode=0
# ldapLoginFilterUsername toggles whether the username attribute participates in login (0 or 1).
ldapLoginFilterUsername=1
# ldapMatchingRuleInChainState indicates if the server supports the matching rule in chain control (unknown, yes, no).
ldapMatchingRuleInChainState=yes
# ldapNestedGroups enables recursive resolution of nested LDAP groups (0 disable, 1 enable).
ldapNestedGroups=1
# ldapOverrideMainServer allows defining a dedicated read-only server for certain operations.
ldapOverrideMainServer=
# ldapPagingSize determines how many LDAP entries are fetched per page request.
ldapPagingSize=500
# ldapPort sets the port for the primary LDAP server (389 for LDAP, 636 for LDAPS).
ldapPort=636
# ldapQuotaAttribute points to the attribute providing user storage quota.
ldapQuotaAttribute=
# ldapQuotaDefault sets the default storage quota if the attribute is empty.
ldapQuotaDefault=
# ldapTLS toggles STARTTLS for LDAP connections (0 disabled, 1 enabled).
ldapTLS=0
# ldapUserAvatarRule determines how user avatars are fetched (default or attribute-based).
ldapUserAvatarRule=default
# ldapUserDisplayName selects the LDAP attribute displayed as the user’s full name.
ldapUserDisplayName=displayName
# ldapUserDisplayName2 provides an optional secondary attribute as fallback for display names.
ldapUserDisplayName2=
# ldapUserFilter sets the LDAP filter that selects which users are available in Nextcloud.
ldapUserFilter="(&(objectClass=user)(objectCategory=person))"
# ldapUserFilterGroups lists group DNs users must belong to for inclusion.
ldapUserFilterGroups=
# ldapUserFilterMode controls how the user filter operates (0 standard, 1 LDAP-only, 2 group-based).
ldapUserFilterMode=0
# ldapUserFilterObjectclass limits user discovery to specific object classes.
ldapUserFilterObjectclass="user"
# ldapUuidGroupAttribute determines which attribute is used as the unique ID for groups (auto to let Nextcloud decide).
ldapUuidGroupAttribute="sAMAccountName"
# ldapUuidUserAttribute determines which attribute is used as the unique ID for users (auto to let Nextcloud decide).
ldapUuidUserAttribute=auto
# markRemnantsAsDisabled defines whether orphaned LDAP accounts are flagged as disabled (0 or 1).
markRemnantsAsDisabled=0
# turnOffCertCheck disables certificate validation for LDAP connections (0 recommended, 1 to bypass).
# Default to 0; certificate validation is enforced once the trusted root is installed inside the container.
turnOffCertCheck=0
# turnOnPasswordChange enables password changes through Nextcloud when supported (0 disabled, 1 enabled).
turnOnPasswordChange=0
# useMemberOfToDetectMembership enables memberOf-based group membership detection (0 or 1).
useMemberOfToDetectMembership=1

# apply_ldap_config applies the populated LDAP variables to a running Nextcloud container.
apply_ldap_config() {
  local container="${1:-${NEXTCLOUD_APP_CONTAINER:-nextcloud-app}}"
  local config_id="${2:-$Configuration}"

  if [[ -z "${config_id}" ]]; then
    echo "Configuration ID is empty. Set the Configuration variable or pass it as the second argument." >&2
    return 1
  fi

  if ! command -v docker >/dev/null 2>&1; then
    echo "docker command not available. Install Docker or ensure it is on PATH." >&2
    return 1
  fi

  if ! docker ps --format '{{.Names}}' | grep -Fxq "${container}"; then
    echo "Container ${container} is not running. Start the stack before applying LDAP settings." >&2
    return 1
  fi

  local -a occ_cmd=(docker exec --user www-data "${container}" php occ)

  if ! "${occ_cmd[@]}" ldap:show-config "${config_id}" >/dev/null 2>&1; then
    echo "Configuration ${config_id} not found; creating new LDAP configuration."
    local create_output
    if ! create_output=$("${occ_cmd[@]}" ldap:create-empty-config 2>&1); then
      echo "Failed to create new LDAP configuration: ${create_output}" >&2
      return 1
    fi
    local created_id
    created_id=$(grep -oE 's[0-9]+' <<<"${create_output}" | head -n 1)
    if [[ -z "${created_id}" ]]; then
      echo "Unable to determine configuration identifier from creation output: ${create_output}" >&2
      return 1
    fi
    if [[ "${created_id}" != "${config_id}" ]]; then
      echo "Created configuration ${created_id}; continuing with that identifier." >&2
      echo "Update the Configuration variable or pass ${created_id} as the second argument for future runs." >&2
      config_id="${created_id}"
    fi
  else
    if [[ -t 0 && -t 1 ]]; then
      local overwrite_response
      read -r -p "Configuration ${config_id} exists. Overwrite settings? [y/N]: " overwrite_response
      case "${overwrite_response}" in
        [yY]|[yY][eE][sS]) ;;
        *) echo "Aborting without applying LDAP settings."; return 0 ;;
      esac
    else
      echo "Configuration ${config_id} exists. Overwrite confirmation not possible in non-interactive mode." >&2
      return 1
    fi
  fi

  local -a config_keys=()
  while IFS= read -r var; do
    config_keys+=("${var}")
  done < <(compgen -v | grep -E '^(ldap[A-Z].*|hasMemberOfFilterSupport|homeFolderNamingRule|lastJpegPhotoLookup|markRemnantsAsDisabled|turnOffCertCheck|turnOnPasswordChange|useMemberOfToDetectMembership)$' | sort)

  if ((${#config_keys[@]} == 0)); then
    echo "No LDAP configuration variables detected to apply." >&2
    return 1
  fi

  for key in "${config_keys[@]}"; do
    local value="${!key}"
    if [[ -z "${value}" ]]; then
      continue
    fi
    local display_value="${value}"
    if [[ "${key}" == "ldapAgentPassword" ]]; then
      display_value="********"
    fi
    echo "Setting ${key}=${display_value}"
    if ! "${occ_cmd[@]}" ldap:set-config "${config_id}" "${key}" "${value}"; then
      echo "Failed to apply ${key} for configuration ${config_id}." >&2
      return 1
    fi
  done

  echo "LDAP configuration ${config_id} applied to container ${container}."

  local occ_display_cmd="docker exec --user www-data ${container} php occ"
  echo "Before enabling, test this configuration using:"
  echo "  ${occ_display_cmd} ldap:config-test ${config_id}"

  if [[ -t 0 && -t 1 ]]; then
    local enable_response desired_status
    while true; do
      read -r -p "Enable configuration ${config_id} now? [y/N]: " enable_response
      case "${enable_response}" in
        [yY]|[yY][eE][sS])
          desired_status=1
          break
          ;;
        [nN]|[nN][oO]|"")
          desired_status=0
          break
          ;;
        *)
          echo "Please answer yes or no."
          ;;
      esac
    done

    if ! "${occ_cmd[@]}" ldap:set-config "${config_id}" ldapConfigurationActive "${desired_status}"; then
      echo "Failed to update ldapConfigurationActive for configuration ${config_id}." >&2
      return 1
    fi

    if [[ "${desired_status}" -eq 1 ]]; then
      echo "LDAP configuration ${config_id} enabled."
    else
      echo "LDAP configuration ${config_id} disabled."
    fi
  else
    echo "Non-interactive mode detected; adjust the configuration status manually:"
    echo "  ${occ_display_cmd} ldap:set-config ${config_id} ldapConfigurationActive 1  # enable"
    echo "  ${occ_display_cmd} ldap:set-config ${config_id} ldapConfigurationActive 0  # disable"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  apply_ldap_config "${1:-${NEXTCLOUD_APP_CONTAINER}}" "${2:-$Configuration}"
fi
