#!/usr/bin/env python3
"""
Test script to verify app name normalization
"""

def normalize_app_name(app_name: str) -> str:
    """
    标准化应用名称，合并辅助进程到主应用
    
    规则：
    1. 如果包含 ' Helper'（区分大小写），取之前的部分
    2. 清理尾部的不完整截断标记（如 ' (' 或 ' ('）
    3. 去除首尾空格
    """
    normalized = app_name
    
    # 1. 如果包含 ' Helper'，截取之前的部分
    if ' Helper' in normalized:
        normalized = normalized.split(' Helper')[0]
    
    # 2. 清理尾部的不完整括号
    normalized = normalized.rstrip(' (')
    normalized = normalized.rstrip(' （')  # 中文括号
    
    # 3. 去除首尾空格
    normalized = normalized.strip()
    
    return normalized if normalized else app_name


# 测试用例
test_cases = [
    # Cursor 系列
    ("Cursor", "Cursor"),
    ("Cursor Helper", "Cursor"),
    ("Cursor Helper (GPU)", "Cursor"),
    ("Cursor Helper (Renderer)", "Cursor"),
    ("Cursor Helper (", "Cursor"),  # 不完整的截断
    
    # Chrome 系列
    ("Google Chrome", "Google Chrome"),
    ("Google Chrome Helper", "Google Chrome"),
    ("Google Chrome Helper (Renderer)", "Google Chrome"),
    ("Google Chrome Helper (GPU)", "Google Chrome"),
    
    # Edge 系列
    ("Microsoft Edge", "Microsoft Edge"),
    ("Microsoft Edge Helper", "Microsoft Edge"),
    ("Microsoft Edge Helper (Renderer)", "Microsoft Edge"),
    
    # 中文应用
    ("企业微信", "企业微信"),
    ("微信", "微信"),
    ("QQ", "QQ"),
    
    # 边缘情况
    ("Safari", "Safari"),
    ("Safari Helper (", "Safari"),  # 截断的括号
    ("App With Spaces", "App With Spaces"),
    ("App Helper With More Text", "App"),  # 只取 Helper 前的部分
    
    # 特殊情况
    ("  Spaces App  ", "Spaces App"),  # 前后空格
    ("Helper", ""),  # 只有 Helper（应返回原值）
]

print("=== App Name Normalization Tests ===\n")
print(f"{'Input':<40} {'Expected':<30} {'Result':<30} {'Status'}")
print("-" * 110)

passed = 0
failed = 0

for input_name, expected in test_cases:
    result = normalize_app_name(input_name)
    # 特殊处理：如果期望是空但输入不是空，允许返回原值
    if expected == "" and result == input_name.strip():
        status = "✓ PASS"
        passed += 1
    elif result == expected:
        status = "✓ PASS"
        passed += 1
    else:
        status = "✗ FAIL"
        failed += 1
    
    print(f"{input_name:<40} {expected:<30} {result:<30} {status}")

print("-" * 110)
print(f"\nTotal: {len(test_cases)} tests")
print(f"Passed: {passed}")
print(f"Failed: {failed}")

if failed == 0:
    print("\n✅ All tests passed!")
else:
    print(f"\n❌ {failed} test(s) failed!")
    exit(1)

# 实际场景测试
print("\n=== Real-world Scenarios ===\n")

scenarios = {
    "Cursor with helpers": [
        "Cursor",
        "Cursor Helper",
        "Cursor Helper (GPU)",
        "Cursor Helper (Renderer)"
    ],
    "Chrome with helpers": [
        "Google Chrome",
        "Google Chrome Helper",
        "Google Chrome Helper (Renderer)",
        "Google Chrome Helper (GPU)"
    ],
    "Chinese apps": [
        "企业微信",
        "微信",
        "QQ"
    ]
}

for scenario_name, apps in scenarios.items():
    print(f"{scenario_name}:")
    normalized = set(normalize_app_name(app) for app in apps)
    print(f"  Input apps: {len(apps)}")
    print(f"  After normalization: {len(normalized)}")
    print(f"  Result: {sorted(normalized)}")
    print()

print("✅ Normalization test complete!")
