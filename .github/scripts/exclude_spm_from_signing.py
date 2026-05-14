#!/usr/bin/env python3
"""
Скрипт для CI: убирает PROVISIONING_PROFILE_SPECIFIER и CODE_SIGN_ENTITLEMENTS у всего,
кроме нативных таргетов приложения и расширения (SPM в project.pbxproj отдельных XCBuildConfiguration не создаёт).

Задаёт bundle id из переменных окружения (секреты GitHub Actions):
  CI_PRODUCT_BUNDLE_IDENTIFIER — основной таргет (все Debug/Release конфиги);
  EXTENSION_BUNDLE_IDENTIFIER — таргет расширения (все конфиги), если расширение есть в проекте.

Вставляет PROVISIONING_PROFILE_SPECIFIER в Release для приложения и расширения, затем
CODE_SIGN_STYLE = Manual и CODE_SIGN_IDENTITY (из CI_CODE_SIGN_IDENTITY) только для этих Release.
Глобальные CODE_SIGN_STYLE / CODE_SIGN_IDENTITY в xcodebuild не используются — иначе SPM (Firebase)
получают Apple Distribution при Automatic signing.
"""

import re
import sys
import os

def find_build_config_variants(content, build_config_id):
    """Находит блок XCBuildConfiguration по id (Debug или Release)."""
    variants = []
    pattern = rf'(\t\t{re.escape(build_config_id)} /\* [^*]+ \*/ = \{{)(.*?)(\t\t\}};)'
    match = re.search(pattern, content, flags=re.DOTALL)
    if match:
        variants.append(("VARIANT_COMMENT", match))
    pattern2 = rf'(\t\t{re.escape(build_config_id)} = \{{)(.*?)(\t\t\}};)'
    match2 = re.search(pattern2, content, flags=re.DOTALL)
    if match2:
        variants.append(("VARIANT_NO_COMMENT", match2))
    return variants


def find_release_config_variants(content, release_config_id):
    """Пробует множество вариантов поиска Release конфигурации"""
    variants = []
    
    # Вариант 1: С комментарием "Release"
    pattern1 = rf'(\t\t{re.escape(release_config_id)} /\* Release \*\/ = \{{)(.*?)(\t\t\}};)'
    match1 = re.search(pattern1, content, flags=re.DOTALL)
    if match1:
        variants.append(("VARIANT_1: With comment 'Release'", match1))
    
    # Вариант 2: Без комментария
    pattern2 = rf'(\t\t{re.escape(release_config_id)} = \{{)(.*?)(\t\t\}};)'
    match2 = re.search(pattern2, content, flags=re.DOTALL)
    if match2:
        variants.append(("VARIANT_2: Without comment", match2))
    
    # Вариант 3: С любым комментарием
    pattern3 = rf'(\t\t{re.escape(release_config_id)} /\* [^*]+ \*/ = \{{)(.*?)(\t\t\}};)'
    match3 = re.search(pattern3, content, flags=re.DOTALL)
    if match3:
        variants.append(("VARIANT_3: With any comment", match3))
    
    # Вариант 4: С пробелами вместо табуляции
    pattern4 = rf'( {re.escape(release_config_id)} /\* Release \*\/ = \{{)(.*?)( \}};)'
    match4 = re.search(pattern4, content, flags=re.DOTALL)
    if match4:
        variants.append(("VARIANT_4: With spaces instead of tabs", match4))
    
    # Вариант 5: Поиск всех конфигураций и выбор Release по содержимому
    all_configs_pattern = r'(\t\t)(\w{24}) (/\* [^*]+ \*/ = \{)(.*?)(\t\t\};)'
    for match in re.finditer(all_configs_pattern, content, flags=re.DOTALL):
        config_id = match.group(2)
        config_body = match.group(4)
        if config_id == release_config_id and 'Release' in match.group(3):
            variants.append(("VARIANT_5: Found by content check", match))
            break
    
    return variants

def add_provisioning_profile_variants(config_body, profile_uuid, target_name="LocalyHealthProject"):
    """Пробует множество вариантов добавления PROVISIONING_PROFILE_SPECIFIER"""
    variants = []
    
    # Удаляем старый PROVISIONING_PROFILE_SPECIFIER, если есть
    clean_body = re.sub(r'\t\t\t\tPROVISIONING_PROFILE_SPECIFIER\s*=\s*[^;]+;\s*\n?', '', config_body)
    
    # Вариант 1: После CODE_SIGN_ENTITLEMENTS
    entitlements_pattern = f'CODE_SIGN_ENTITLEMENTS = {target_name}/{target_name}.entitlements;'
    if entitlements_pattern in clean_body:
        new_body = clean_body.replace(
            entitlements_pattern,
            f'{entitlements_pattern}\n\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = {profile_uuid};'
        )
        variants.append(("INSERT_VARIANT_1: After CODE_SIGN_ENTITLEMENTS", new_body))
    
    # Вариант 2: После CODE_SIGN_STYLE
    if 'CODE_SIGN_STYLE' in clean_body:
        new_body = re.sub(
            r'(CODE_SIGN_STYLE = [^;]+;)',
            rf'\1\n\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = {profile_uuid};',
            clean_body
        )
        variants.append(("INSERT_VARIANT_2: After CODE_SIGN_STYLE", new_body))
    
    # Вариант 3: После DEVELOPMENT_TEAM
    if 'DEVELOPMENT_TEAM' in clean_body:
        new_body = re.sub(
            r'(DEVELOPMENT_TEAM = [^;]+;)',
            rf'\1\n\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = {profile_uuid};',
            clean_body
        )
        variants.append(("INSERT_VARIANT_3: After DEVELOPMENT_TEAM", new_body))
    
    # Вариант 4: После PRODUCT_BUNDLE_IDENTIFIER
    if 'PRODUCT_BUNDLE_IDENTIFIER' in clean_body:
        new_body = re.sub(
            r'(PRODUCT_BUNDLE_IDENTIFIER = [^;]+;)',
            rf'\1\n\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = {profile_uuid};',
            clean_body
        )
        variants.append(("INSERT_VARIANT_4: After PRODUCT_BUNDLE_IDENTIFIER", new_body))
    
    # Вариант 5: В начало buildSettings (после открывающей скобки)
    if 'buildSettings = {' in clean_body:
        build_settings_start = clean_body.find('buildSettings = {') + len('buildSettings = {')
        new_body = (
            clean_body[:build_settings_start] + 
            f'\n\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = {profile_uuid};' +
            clean_body[build_settings_start:]
        )
        variants.append(("INSERT_VARIANT_5: At beginning of buildSettings", new_body))
    
    # Вариант 6: В конец buildSettings (перед закрывающей скобкой)
    if 'buildSettings = {' in clean_body:
        build_settings_end = clean_body.rfind('\t\t\t};')
        if build_settings_end > 0:
            new_body = (
                clean_body[:build_settings_end] + 
                f'\n\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = {profile_uuid};' +
                clean_body[build_settings_end:]
            )
            variants.append(("INSERT_VARIANT_6: At end of buildSettings", new_body))
    
    # Вариант 7: После CODE_SIGN_IDENTITY
    if 'CODE_SIGN_IDENTITY' in clean_body:
        new_body = re.sub(
            r'(CODE_SIGN_IDENTITY = [^;]+;)',
            rf'\1\n\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = {profile_uuid};',
            clean_body
        )
        variants.append(("INSERT_VARIANT_7: After CODE_SIGN_IDENTITY", new_body))
    
    # Вариант 8: В начало конфигурации (после isa = XCBuildConfiguration)
    if 'isa = XCBuildConfiguration;' in clean_body:
        isa_pos = clean_body.find('isa = XCBuildConfiguration;') + len('isa = XCBuildConfiguration;')
        new_body = (
            clean_body[:isa_pos] + 
            f'\n\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = {profile_uuid};' +
            clean_body[isa_pos:]
        )
        variants.append(("INSERT_VARIANT_8: After isa = XCBuildConfiguration", new_body))
    
    # Вариант 9: Просто в начало buildSettings блока
    if 'buildSettings = {' in clean_body:
        # Находим первую строку после buildSettings = {
        lines = clean_body.split('\n')
        new_lines = []
        inserted = False
        for line in lines:
            new_lines.append(line)
            if 'buildSettings = {' in line and not inserted:
                new_lines.append(f'\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = {profile_uuid};')
                inserted = True
        new_body = '\n'.join(new_lines)
        variants.append(("INSERT_VARIANT_9: First line after buildSettings = {", new_body))
    
    # Вариант 10: Fallback - просто в начало
    new_body = f'\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = {profile_uuid};\n' + clean_body.lstrip('\t')
    variants.append(("INSERT_VARIANT_10: At very beginning (fallback)", new_body))
    
    return variants


def collect_target_build_configuration_ids(content, target_name):
    """
    Все XCBuildConfiguration id (Debug/Release) для PBXNativeTarget с данным именем,
    плюс id Release-конфигурации. Паттерн жёстко привязан к isa = PBXNativeTarget сразу после «= {»,
    чтобы не совпасть с PBXGroup / PBXFileReference с тем же комментарием.
    """
    target_section_pattern = (
        rf'(\w{{24}}) /\* {re.escape(target_name)} \*/ = \{{\n'
        rf'\t\t\tisa = PBXNativeTarget;\n'
        rf'\t\t\tbuildConfigurationList = (\w{{24}})'
    )
    target_section_match = re.search(target_section_pattern, content, flags=re.DOTALL)
    if not target_section_match:
        return set(), None
    config_list_id = target_section_match.group(2)
    config_list_pattern = rf'{re.escape(config_list_id)} /\* Build configuration list[^}}]*?buildConfigurations = \(([^)]+)\);'
    config_list_match = re.search(config_list_pattern, content, flags=re.DOTALL)
    if not config_list_match:
        config_list_pattern_alt = rf'{re.escape(config_list_id)}[^=]*=.*?buildConfigurations\s*=\s*\(([^)]+)\);'
        config_list_match = re.search(config_list_pattern_alt, content, flags=re.DOTALL)
    if not config_list_match:
        return set(), None
    config_ids_text = config_list_match.group(1)
    ids = set()
    release_config_id = None
    for match in re.finditer(r'(\w{24}) /\* (Debug|Release) \*/', config_ids_text):
        cid = match.group(1)
        ids.add(cid)
        if match.group(2) == 'Release':
            release_config_id = cid
    if not release_config_id:
        for match in re.finditer(r'(\w{24})', config_ids_text):
            cid = match.group(1)
            ids.add(cid)
            if rf'{cid} /\* Release \*/' in content:
                release_config_id = cid
                break
    return ids, release_config_id


def apply_provisioning_profile_to_release_config(new_content, release_config_id, profile_uuid, target_name):
    """Вставляет PROVISIONING_PROFILE_SPECIFIER в Release-блок указанной конфигурации."""
    find_variants = find_build_config_variants(new_content, release_config_id)
    if not find_variants:
        find_variants = find_release_config_variants(new_content, release_config_id)
    if not find_variants:
        return new_content, False
    for find_variant_name, find_match in find_variants:
        config_header = find_match.group(1)
        config_body = find_match.group(2)
        config_footer = find_match.group(3)
        if f'PROVISIONING_PROFILE_SPECIFIER = {profile_uuid}' in config_body:
            return new_content, True
        insert_variants = add_provisioning_profile_variants(config_body, profile_uuid, target_name)
        for insert_variant_name, new_config_body in insert_variants:
            if f'PROVISIONING_PROFILE_SPECIFIER = {profile_uuid}' in new_config_body:
                new_content = (
                    new_content[: find_match.start()]
                    + config_header
                    + new_config_body
                    + config_footer
                    + new_content[find_match.end() :]
                )
                return new_content, True
    return new_content, False


def patch_product_bundle_identifier_in_config(new_content, build_config_id, bundle_id):
    """Подменяет PRODUCT_BUNDLE_IDENTIFIER в указанной XCBuildConfiguration (Debug или Release)."""
    find_variants = find_build_config_variants(new_content, build_config_id)
    if not find_variants:
        return new_content, False
    escaped = bundle_id.replace('\\', '\\\\').replace('"', '\\"')
    line = f'\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "{escaped}";'
    for _find_variant_name, find_match in find_variants:
        config_header = find_match.group(1)
        config_body = find_match.group(2)
        config_footer = find_match.group(3)
        if re.search(r'\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER\s*=\s*[^;]+;', config_body):
            new_body = re.sub(
                r'\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER\s*=\s*[^;]+;',
                line,
                config_body,
                count=1,
            )
        else:
            new_body = re.sub(
                r'(buildSettings = \{)',
                rf'\1\n{line}',
                config_body,
                count=1,
            )
        new_content = (
            new_content[: find_match.start()]
            + config_header
            + new_body
            + config_footer
            + new_content[find_match.end() :]
        )
        return new_content, True
    return new_content, False


def patch_code_sign_style_in_config(new_content, build_config_id, style):
    """Выставляет CODE_SIGN_STYLE (Manual / Automatic) в указанной конфигурации."""
    find_variants = find_build_config_variants(new_content, build_config_id)
    if not find_variants:
        return new_content, False
    line = f"\t\t\t\tCODE_SIGN_STYLE = {style};"
    for _name, find_match in find_variants:
        config_header = find_match.group(1)
        config_body = find_match.group(2)
        config_footer = find_match.group(3)
        if re.search(r"\t\t\t\tCODE_SIGN_STYLE\s*=\s*[^;]+;", config_body):
            new_body = re.sub(
                r"\t\t\t\tCODE_SIGN_STYLE\s*=\s*[^;]+;",
                line,
                config_body,
                count=1,
            )
        else:
            new_body = re.sub(
                r"(buildSettings = \{)",
                rf"\1\n{line}",
                config_body,
                count=1,
            )
        new_content = (
            new_content[: find_match.start()]
            + config_header
            + new_body
            + config_footer
            + new_content[find_match.end() :]
        )
        return new_content, True
    return new_content, False


def patch_code_sign_identity_in_config(new_content, build_config_id, identity):
    """Выставляет CODE_SIGN_IDENTITY (в кавычках, как в Xcode) только в указанной конфигурации."""
    if not identity:
        return new_content, False
    find_variants = find_build_config_variants(new_content, build_config_id)
    if not find_variants:
        return new_content, False
    escaped = identity.replace("\\", "\\\\").replace('"', '\\"')
    line = f'\t\t\t\tCODE_SIGN_IDENTITY = "{escaped}";'
    for _name, find_match in find_variants:
        config_header = find_match.group(1)
        config_body = find_match.group(2)
        config_footer = find_match.group(3)
        if re.search(r"\t\t\t\tCODE_SIGN_IDENTITY\s*=\s*[^;]+;", config_body):
            new_body = re.sub(
                r"\t\t\t\tCODE_SIGN_IDENTITY\s*=\s*[^;]+;",
                line,
                config_body,
                count=1,
            )
        else:
            new_body = re.sub(
                r"(buildSettings = \{)",
                rf"\1\n{line}",
                config_body,
                count=1,
            )
        new_content = (
            new_content[: find_match.start()]
            + config_header
            + new_body
            + config_footer
            + new_content[find_match.end() :]
        )
        return new_content, True
    return new_content, False


def exclude_spm_from_signing(
    pbxproj_path,
    profile_uuid=None,
    target_name="LocalyHealthProject",
    extension_profile_uuid=None,
    extension_target_name="GlowBounceNotificationService",
):
    """
    Убирает PROVISIONING_PROFILE_SPECIFIER / CODE_SIGN_ENTITLEMENTS у SPM-таргетов.
    Задаёт PROVISIONING_PROFILE_SPECIFIER для основного приложения и (при наличии в проекте)
    для нативного расширения (например GlowBounceNotificationService) — отдельный UUID профиля.
    """
    if not os.path.exists(pbxproj_path):
        print(f"❌ Error: File {pbxproj_path} not found")
        sys.exit(1)
    
    with open(pbxproj_path, 'r') as f:
        content = f.read()
    
    original_content = content
    new_content = content
    changes_made = False
    
    # Находим ID основного таргета приложения
    # Пробуем множество вариантов поиска таргета
    main_config_ids = set()
    release_config_id = None
    config_list_id = None
    
    print(f"🔍 Trying multiple variants to find main target '{target_name}'...")
    
    # Вариант 1: Стандартный паттерн с табуляцией
    main_target_pattern1 = rf'PBXNativeTarget "{re.escape(target_name)}" = \{{.*?buildConfigurationList = (\w{{24}})'
    main_target_match = re.search(main_target_pattern1, content, flags=re.DOTALL)
    if main_target_match:
        config_list_id = main_target_match.group(1)
        print(f"✅ VARIANT_1: Found main target with standard pattern, config list ID: {config_list_id}")
    
    # Вариант 2: С пробелами вместо табуляции
    if not config_list_id:
        main_target_pattern2 = rf'PBXNativeTarget "{re.escape(target_name)}"\s*=\s*\{{.*?buildConfigurationList\s*=\s*(\w{{24}})'
        main_target_match = re.search(main_target_pattern2, content, flags=re.DOTALL)
        if main_target_match:
            config_list_id = main_target_match.group(1)
            print(f"✅ VARIANT_2: Found main target with spaces pattern, config list ID: {config_list_id}")
    
    # Вариант 3: Поиск по имени в комментарии buildConfigurationList
    if not config_list_id:
        config_list_pattern3 = rf'(\w{{24}}) /\* Build configuration list for PBXNativeTarget "{re.escape(target_name)}" \*/'
        config_list_match3 = re.search(config_list_pattern3, content)
        if config_list_match3:
            config_list_id = config_list_match3.group(1)
            print(f"✅ VARIANT_3: Found config list by comment, ID: {config_list_id}")
    
    # Вариант 4: Поиск всех PBXNativeTarget и выбор первого (обычно это основной таргет)
    if not config_list_id:
        all_targets_pattern = rf'(\w{{24}}) /\* {re.escape(target_name)} \*/ = \{{.*?buildConfigurationList = (\w{{24}})'
        all_targets_match = re.search(all_targets_pattern, content, flags=re.DOTALL)
        if all_targets_match:
            config_list_id = all_targets_match.group(2)
            print(f"✅ VARIANT_4: Found main target by ID pattern, config list ID: {config_list_id}")
    
    # Вариант 5: Поиск по структуре - находим таргет с указанным именем
    if not config_list_id:
        target_section_pattern = rf'(\w{{24}}) /\* {re.escape(target_name)} \*/ = \{{.*?isa = PBXNativeTarget;.*?buildConfigurationList = (\w{{24}})'
        target_section_match = re.search(target_section_pattern, content, flags=re.DOTALL)
        if target_section_match:
            config_list_id = target_section_match.group(2)
            print(f"✅ VARIANT_5: Found main target by structure, config list ID: {config_list_id}")
    
    # Вариант 6: Поиск по имени без кавычек
    if not config_list_id:
        main_target_pattern6 = rf'PBXNativeTarget\s+{re.escape(target_name)}\s*=\s*\{{.*?buildConfigurationList\s*=\s*(\w{{24}})'
        main_target_match6 = re.search(main_target_pattern6, content, flags=re.DOTALL)
        if main_target_match6:
            config_list_id = main_target_match6.group(1)
            print(f"✅ VARIANT_6: Found main target without quotes, config list ID: {config_list_id}")
    
    if not config_list_id:
        print(f"❌ Error: Could not find main target '{target_name}' by any method")
        print(f"🔍 Debug: Searching for '{target_name}' in file...")
        if target_name in content:
            matches = re.findall(rf'PBXNativeTarget[^}}]*{re.escape(target_name)}[^}}]*', content, re.DOTALL)
            print(f"Found {len(matches)} potential matches")
            for i, match in enumerate(matches[:3]):  # Показываем первые 3
                print(f"  Match {i+1}: {match[:200]}...")
        sys.exit(1)
    
    # Находим список конфигураций
    config_list_pattern = rf'{re.escape(config_list_id)} /\* Build configuration list[^}}]*?buildConfigurations = \(([^)]+)\);'
    config_list_match = re.search(config_list_pattern, content, flags=re.DOTALL)
    
    if not config_list_match:
        # Пробуем альтернативный паттерн без комментария
        config_list_pattern_alt = rf'{re.escape(config_list_id)}[^=]*=.*?buildConfigurations\s*=\s*\(([^)]+)\);'
        config_list_match = re.search(config_list_pattern_alt, content, flags=re.DOTALL)
    
    if config_list_match:
        config_ids_text = config_list_match.group(1)
        print(f"🔍 Config list text: {config_ids_text[:200]}...")
        
        # Извлекаем все ID конфигураций и находим Release
        for match in re.finditer(r'(\w{24}) /\* (Debug|Release) \*/', config_ids_text):
            config_id = match.group(1)
            config_type = match.group(2)
            main_config_ids.add(config_id)
            if config_type == 'Release':
                release_config_id = config_id
                print(f"✅ Found Release config ID: {release_config_id}")
        
        # Если не нашли через комментарий, пробуем без комментария
        if not release_config_id:
            for match in re.finditer(r'(\w{24})', config_ids_text):
                config_id = match.group(1)
                main_config_ids.add(config_id)
                # Проверяем, является ли это Release конфигурацией по содержимому
                release_check_pattern = rf'{re.escape(config_id)} /\* Release \*/'
                if release_check_pattern in content:
                    release_config_id = config_id
                    print(f"✅ Found Release config ID (by content check): {release_config_id}")
                    break
        
        print(f"✅ Found main target configurations: {main_config_ids}")
    else:
        print(f"❌ Error: Could not find config list for main target")
        sys.exit(1)
    
    if not release_config_id:
        print(f"❌ Error: Could not find Release configuration ID")
        sys.exit(1)
    
    ext_ids, ext_release_config_id = collect_target_build_configuration_ids(content, extension_target_name)
    protected_config_ids = set(main_config_ids)
    if ext_ids:
        protected_config_ids |= ext_ids
        print(f"✅ Native extension '{extension_target_name}' build configuration IDs: {ext_ids}")
        if profile_uuid and not extension_profile_uuid:
            print(
                f"❌ Error: Extension target '{extension_target_name}' is present. Add GitHub secret "
                "APPSTORE_CONNECT_EXTENSION_PROVISIONING_PROFILE (distribution profile for the extension App ID) "
                "and pass its provisioning profile UUID as the 4th script argument."
            )
            sys.exit(1)
        ext_bundle_env = os.environ.get("EXTENSION_BUNDLE_IDENTIFIER", "").strip()
        if profile_uuid and not ext_bundle_env:
            print(
                "❌ Error: Set GitHub Actions secret EXTENSION_BUNDLE_IDENTIFIER to the extension's "
                "PRODUCT_BUNDLE_IDENTIFIER (must match the App ID in the extension provisioning profile)."
            )
            sys.exit(1)
    
    # Удаляем PROVISIONING_PROFILE_SPECIFIER и CODE_SIGN_ENTITLEMENTS из всех конфигураций,
    # кроме основного приложения и указанных нативных таргетов (не SPM).
    config_section_pattern = r'(\t\t)(\w{24}) (/\* [^*]+ \*/ = \{)(.*?)(\t\t\};)'
    
    def clean_non_main_configs(match):
        nonlocal changes_made
        indent = match.group(1)
        config_id = match.group(2)
        config_header = match.group(3)
        config_body = match.group(4)
        config_footer = match.group(5)
        
        # Если это не конфигурация защищённого нативного таргета — чистим (SPM и прочее).
        if config_id not in protected_config_ids:
            original_body = config_body
            # Удаляем PROVISIONING_PROFILE_SPECIFIER
            config_body = re.sub(r'\t\t\t\tPROVISIONING_PROFILE_SPECIFIER\s*=\s*[^;]+;\s*\n?', '', config_body)
            # Удаляем CODE_SIGN_ENTITLEMENTS
            config_body = re.sub(r'\t\t\t\tCODE_SIGN_ENTITLEMENTS\s*=\s*[^;]+;\s*\n?', '', config_body)
            if original_body != config_body:
                changes_made = True
                return indent + config_id + ' ' + config_header + config_body + config_footer
        
        return match.group(0)
    
    new_content = re.sub(config_section_pattern, clean_non_main_configs, new_content, flags=re.DOTALL)
    
    if profile_uuid:
        ci_main_bundle = os.environ.get("CI_PRODUCT_BUNDLE_IDENTIFIER", "").strip()
        if not ci_main_bundle:
            print(
                "❌ Error: CI_PRODUCT_BUNDLE_IDENTIFIER is not set. The workflow should export it from "
                "secret BUNDLE_IDENTIFIER before running this script."
            )
            sys.exit(1)
        print(f"🔧 Patching main target bundle id (all configs) -> {ci_main_bundle}")
        for cid in sorted(main_config_ids):
            new_content, ok = patch_product_bundle_identifier_in_config(new_content, cid, ci_main_bundle)
            if not ok:
                print(f"❌ Error: Could not set PRODUCT_BUNDLE_IDENTIFIER for main config {cid}")
                sys.exit(1)
            changes_made = True

        ext_bundle_env = os.environ.get("EXTENSION_BUNDLE_IDENTIFIER", "").strip()
        if ext_ids:
            print(f"🔧 Patching extension bundle id (all configs) -> {ext_bundle_env}")
            for cid in sorted(ext_ids):
                new_content, ok = patch_product_bundle_identifier_in_config(new_content, cid, ext_bundle_env)
                if not ok:
                    print(f"❌ Error: Could not set PRODUCT_BUNDLE_IDENTIFIER for extension config {cid}")
                    sys.exit(1)
                changes_made = True

        print(f"🔧 Adding PROVISIONING_PROFILE_SPECIFIER to main app Release ({target_name}): {profile_uuid}")
        new_content, ok_main = apply_provisioning_profile_to_release_config(
            new_content, release_config_id, profile_uuid, target_name
        )
        if not ok_main:
            print("❌ Error: Could not add PROVISIONING_PROFILE_SPECIFIER for main target")
            sys.exit(1)
        changes_made = True
        print("✅ Main target Release: PROVISIONING_PROFILE_SPECIFIER applied")

        if extension_profile_uuid and ext_release_config_id:
            print(
                f"🔧 Adding PROVISIONING_PROFILE_SPECIFIER to extension Release ({extension_target_name}): "
                f"{extension_profile_uuid}"
            )
            new_content, ok_ext = apply_provisioning_profile_to_release_config(
                new_content, ext_release_config_id, extension_profile_uuid, extension_target_name
            )
            if not ok_ext:
                print("❌ Error: Could not add PROVISIONING_PROFILE_SPECIFIER for extension target")
                sys.exit(1)
            changes_made = True
            print("✅ Extension Release: PROVISIONING_PROFILE_SPECIFIER applied")

        print("🔧 CODE_SIGN_STYLE = Manual for main + extension Release only (SPM без глобального Manual)")
        new_content, ok_mcs = patch_code_sign_style_in_config(new_content, release_config_id, "Manual")
        if not ok_mcs:
            print("❌ Error: Could not set CODE_SIGN_STYLE for main Release")
            sys.exit(1)
        changes_made = True
        if ext_release_config_id:
            new_content, ok_ecs = patch_code_sign_style_in_config(new_content, ext_release_config_id, "Manual")
            if not ok_ecs:
                print("❌ Error: Could not set CODE_SIGN_STYLE for extension Release")
                sys.exit(1)
            changes_made = True

        sign_id = os.environ.get("CI_CODE_SIGN_IDENTITY", "").strip()
        if not sign_id:
            print(
                "❌ Error: CI_CODE_SIGN_IDENTITY is not set. The workflow should export the resolved "
                "distribution identity string before running this script."
            )
            sys.exit(1)
        print("🔧 CODE_SIGN_IDENTITY only for main + extension Release (SPM не получает identity из CLI)")
        new_content, ok_mid = patch_code_sign_identity_in_config(new_content, release_config_id, sign_id)
        if not ok_mid:
            print("❌ Error: Could not set CODE_SIGN_IDENTITY for main Release")
            sys.exit(1)
        changes_made = True
        if ext_release_config_id:
            new_content, ok_eid = patch_code_sign_identity_in_config(new_content, ext_release_config_id, sign_id)
            if not ok_eid:
                print("❌ Error: Could not set CODE_SIGN_IDENTITY for extension Release")
                sys.exit(1)
            changes_made = True
    
    # Сохраняем изменения
    if changes_made or new_content != original_content:
        with open(pbxproj_path, 'w') as f:
            f.write(new_content)
        print(f"✅ Changes saved to {pbxproj_path}")
    else:
        print(f"ℹ️ No changes needed")
    
    # Проверяем, что PROVISIONING_PROFILE_SPECIFIER был добавлен (если нужно)
    if profile_uuid:
        if 'PROVISIONING_PROFILE_SPECIFIER' not in new_content:
            print("❌ Error: PROVISIONING_PROFILE_SPECIFIER was not added correctly!")
            sys.exit(1)
        matches = re.findall(r'PROVISIONING_PROFILE_SPECIFIER\s*=\s*([^;\n]+)', new_content)
        print(f"🔍 Found PROVISIONING_PROFILE_SPECIFIER entries: {matches}")

        def uuid_present_in_matches(expected_uuid, value_matches):
            if not expected_uuid:
                return True
            for m in value_matches:
                clean_match = m.strip()
                if expected_uuid in clean_match:
                    return True
            exp_norm = expected_uuid.lower().replace("-", "")
            for m in value_matches:
                if exp_norm in m.strip().lower().replace("-", ""):
                    return True
            return False

        required = [profile_uuid]
        if extension_profile_uuid:
            required.append(extension_profile_uuid)
        for uid in required:
            if not uuid_present_in_matches(uid, matches):
                print("❌ Error: PROVISIONING_PROFILE_SPECIFIER missing or UUID mismatch")
                print(f"   Expected UUID present: {uid}")
                print(f"   Found: {matches}")
                sys.exit(1)
        print("✅ Verification: provisioning profile UUID(s) present for native targets; SPM targets cleaned")
    else:
        print("✅ Successfully removed PROVISIONING_PROFILE_SPECIFIER and CODE_SIGN_ENTITLEMENTS from SPM targets")

if __name__ == "__main__":
    if len(sys.argv) < 2 or len(sys.argv) > 6:
        print(
            "Usage: exclude_spm_from_signing.py <pbxproj_path> [profile_uuid] [target_name] "
            "[extension_profile_uuid] [extension_target_name]"
        )
        sys.exit(1)

    pbxproj_path = sys.argv[1]
    profile_uuid = sys.argv[2] if len(sys.argv) > 2 else None
    target_name = sys.argv[3] if len(sys.argv) > 3 else "LocalyHealthProject"
    extension_profile_uuid = sys.argv[4] if len(sys.argv) > 4 else None
    extension_target_name = sys.argv[5] if len(sys.argv) > 5 else "GlowBounceNotificationService"

    if not profile_uuid:
        print("⚠️ Warning: No profile_uuid provided, will only clean SPM targets")

    print(f"📦 Main target: {target_name}")
    if extension_profile_uuid:
        print(f"📦 Extension target: {extension_target_name} (profile UUID provided)")

    exclude_spm_from_signing(
        pbxproj_path,
        profile_uuid,
        target_name,
        extension_profile_uuid,
        extension_target_name,
    )
