#!/usr/bin/env python3
"""
Скрипт для исключения SPM зависимостей от применения лишних настроек подписи.
Удаляет PROVISIONING_PROFILE_SPECIFIER и CODE_SIGN_ENTITLEMENTS из SPM таргетов.
Добавляет PROVISIONING_PROFILE_SPECIFIER только для основного таргета.
Пробует множество вариантов поиска и добавления, логирует успешный.
"""

import re
import sys
import os

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

def exclude_spm_from_signing(pbxproj_path, profile_uuid=None, target_name="LocalyHealthProject"):
    """
    Исключает SPM зависимости от применения PROVISIONING_PROFILE_SPECIFIER и CODE_SIGN_ENTITLEMENTS.
    Если указан profile_uuid, добавляет его только для основного таргета.
    
    Args:
        pbxproj_path: Путь к project.pbxproj файлу
        profile_uuid: UUID provisioning profile (опционально, для добавления к основному таргету)
        target_name: Имя основного таргета (по умолчанию LocalyHealthProject)
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
    
    # Удаляем PROVISIONING_PROFILE_SPECIFIER и CODE_SIGN_ENTITLEMENTS из всех конфигураций, кроме основного таргета
    config_section_pattern = r'(\t\t)(\w{24}) (/\* [^*]+ \*/ = \{)(.*?)(\t\t\};)'
    
    def clean_non_main_configs(match):
        nonlocal changes_made
        indent = match.group(1)
        config_id = match.group(2)
        config_header = match.group(3)
        config_body = match.group(4)
        config_footer = match.group(5)
        
        # Если это не конфигурация основного таргета, удаляем лишние настройки
        if config_id not in main_config_ids:
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
    
    # Если указан profile_uuid, добавляем PROVISIONING_PROFILE_SPECIFIER в Release конфигурацию основного таргета
    if profile_uuid:
        print(f"🔧 Adding PROVISIONING_PROFILE_SPECIFIER to Release config: {profile_uuid}")
        print(f"🔄 Trying multiple variants to find and modify Release config...")
        
        # Пробуем найти Release конфигурацию разными способами
        find_variants = find_release_config_variants(new_content, release_config_id)
        
        if not find_variants:
            print(f"❌ Error: Could not find Release config section by any method")
            sys.exit(1)
        
        success = False
        used_find_variant = None
        used_insert_variant = None
        
        # Пробуем каждый вариант поиска
        for find_variant_name, find_match in find_variants:
            print(f"\n🔍 Trying {find_variant_name}...")
            config_header = find_match.group(1)
            config_body = find_match.group(2)
            config_footer = find_match.group(3)
            
            # Проверяем, нет ли уже PROVISIONING_PROFILE_SPECIFIER с правильным UUID
            if f'PROVISIONING_PROFILE_SPECIFIER = {profile_uuid}' in config_body:
                print(f"✅ PROVISIONING_PROFILE_SPECIFIER already set correctly")
                success = True
                used_find_variant = find_variant_name
                used_insert_variant = "Already present"
                break
            
            # Пробуем разные варианты добавления
            insert_variants = add_provisioning_profile_variants(config_body, profile_uuid, target_name)
            
            for insert_variant_name, new_config_body in insert_variants:
                print(f"  📝 Trying {insert_variant_name}...")
                
                # Проверяем, что PROVISIONING_PROFILE_SPECIFIER добавлен
                if f'PROVISIONING_PROFILE_SPECIFIER = {profile_uuid}' in new_config_body:
                    # Заменяем в new_content
                    new_content = new_content[:find_match.start()] + config_header + new_config_body + config_footer + new_content[find_match.end():]
                    changes_made = True
                    success = True
                    used_find_variant = find_variant_name
                    used_insert_variant = insert_variant_name
                    print(f"  ✅ SUCCESS with {insert_variant_name}!")
                    break
            
            if success:
                break
        
        if not success:
            print(f"❌ Error: Could not add PROVISIONING_PROFILE_SPECIFIER by any method")
            sys.exit(1)
        
        # Логируем успешный вариант
        print(f"\n{'='*60}")
        print(f"✅ SUCCESSFUL VARIANT COMBINATION:")
        print(f"   FIND VARIANT: {used_find_variant}")
        print(f"   INSERT VARIANT: {used_insert_variant}")
        print(f"{'='*60}\n")
    
    # Сохраняем изменения
    if changes_made or new_content != original_content:
        with open(pbxproj_path, 'w') as f:
            f.write(new_content)
        print(f"✅ Changes saved to {pbxproj_path}")
    else:
        print(f"ℹ️ No changes needed")
    
    # Проверяем, что PROVISIONING_PROFILE_SPECIFIER был добавлен (если нужно)
    if profile_uuid:
        # Простая проверка: ищем PROVISIONING_PROFILE_SPECIFIER и проверяем, что UUID присутствует
        if 'PROVISIONING_PROFILE_SPECIFIER' in new_content:
            # Ищем все вхождения PROVISIONING_PROFILE_SPECIFIER
            matches = re.findall(r'PROVISIONING_PROFILE_SPECIFIER\s*=\s*([^;\n]+)', new_content)
            print(f"🔍 Found PROVISIONING_PROFILE_SPECIFIER entries: {matches}")
            
            # Проверяем, есть ли наш UUID в найденных значениях
            uuid_found = False
            for match in matches:
                # Убираем пробелы и табуляцию для сравнения
                clean_match = match.strip()
                if profile_uuid in clean_match:
                    uuid_found = True
                    print(f"✅ UUID found in entry: {clean_match}")
                    break
            
            if uuid_found:
                print(f"✅ Verification: PROVISIONING_PROFILE_SPECIFIER with correct UUID found")
                print(f"✅ Successfully configured PROVISIONING_PROFILE_SPECIFIER for main target and removed from SPM targets")
            else:
                # Если UUID не найден точно, проверяем более гибко (без учета регистра и дефисов)
                uuid_normalized = profile_uuid.lower().replace('-', '')
                for match in matches:
                    match_normalized = match.strip().lower().replace('-', '')
                    if uuid_normalized in match_normalized:
                        uuid_found = True
                        print(f"✅ UUID found (normalized comparison): {match.strip()}")
                        print(f"✅ Verification: PROVISIONING_PROFILE_SPECIFIER with correct UUID found")
                        print(f"✅ Successfully configured PROVISIONING_PROFILE_SPECIFIER for main target and removed from SPM targets")
                        break
                
                if not uuid_found:
                    print(f"❌ Error: PROVISIONING_PROFILE_SPECIFIER found but UUID doesn't match!")
                    print(f"   Expected: {profile_uuid}")
                    print(f"   Found: {matches}")
                    sys.exit(1)
        else:
            print(f"❌ Error: PROVISIONING_PROFILE_SPECIFIER was not added correctly!")
            sys.exit(1)
    else:
        print("✅ Successfully removed PROVISIONING_PROFILE_SPECIFIER and CODE_SIGN_ENTITLEMENTS from SPM targets")

if __name__ == "__main__":
    if len(sys.argv) < 2 or len(sys.argv) > 4:
        print("Usage: exclude_spm_from_signing.py <pbxproj_path> [profile_uuid] [target_name]")
        sys.exit(1)
    
    pbxproj_path = sys.argv[1]
    profile_uuid = sys.argv[2] if len(sys.argv) > 2 else None
    target_name = sys.argv[3] if len(sys.argv) > 3 else "LocalyHealthProject"
    
    if not profile_uuid:
        print("⚠️ Warning: No profile_uuid provided, will only clean SPM targets")
    
    print(f"📦 Target project: {target_name}")
    exclude_spm_from_signing(pbxproj_path, profile_uuid, target_name)
