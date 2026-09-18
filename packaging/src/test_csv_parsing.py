#!/usr/bin/env python3
"""
Test script to verify nettop CSV parsing fix
"""
import re
from typing import Dict, Tuple

def parse_nettop_output(output: str) -> Dict[str, Tuple[int, int]]:
    """
    解析 nettop CSV 输出，提取每个进程的字节数
    nettop -J 输出格式：,bytes_in,bytes_out,
                     进程名.PID,字节数,字节数,
    返回: {app_name: (bytes_in, bytes_out)}
    """
    traffic_data = {}
    lines = output.strip().split('\n')
    
    for line in lines:
        line = line.strip()
        
        # 跳过空行和表头
        if not line or line.startswith(',bytes_in,') or line == ',bytes_in,bytes_out,':
            continue
        
        # 按逗号分割 CSV
        parts = line.split(',')
        if len(parts) < 3:
            continue
        
        try:
            # 第一列是进程名（可能带.PID后缀）
            process_name = parts[0].strip()
            if not process_name:
                continue
            
            # 去除 .PID 后缀（如 "mDNSResponder.193" -> "mDNSResponder"）
            app_name = re.sub(r'\.\d+$', '', process_name)
            
            # 最后两个数字字段是 bytes_in 和 bytes_out
            bytes_in = int(parts[1].strip())
            bytes_out = int(parts[2].strip())
            
            # 聚合同名应用
            if app_name in traffic_data:
                prev_in, prev_out = traffic_data[app_name]
                traffic_data[app_name] = (prev_in + bytes_in, prev_out + bytes_out)
            else:
                traffic_data[app_name] = (bytes_in, bytes_out)
                
        except (ValueError, IndexError) as e:
            # 跳过无法解析的行
            continue
    
    return traffic_data


# Test with actual macOS nettop output
test_output = """,bytes_in,bytes_out,
mDNSResponder.193,45194469,27357403,
企业微信.1152,525385,177637,
Safari.8821,12345678,9876543,
Safari.8822,11111111,2222222,
Chrome.5000,99999999,88888888,
"""

print("Testing CSV parsing with real macOS nettop output...")
print("-" * 60)
print("Input:")
print(test_output)
print("-" * 60)

result = parse_nettop_output(test_output)

print("\nParsed Results:")
print("-" * 60)
for app_name, (bytes_in, bytes_out) in sorted(result.items()):
    print(f"{app_name:20} | In: {bytes_in:>12,} | Out: {bytes_out:>12,}")
print("-" * 60)

print("\n✅ Test Summary:")
print(f"   - Total apps parsed: {len(result)}")
print(f"   - Header lines skipped: ✓")
print(f"   - PID suffixes stripped: ✓")
print(f"   - Same apps aggregated: ✓ (Safari: 2 processes -> 1 entry)")

# Verify specific expectations
assert len(result) == 4, f"Expected 4 apps, got {len(result)}"
assert "mDNSResponder" in result, "mDNSResponder should be parsed"
assert "企业微信" in result, "Chinese app name should be parsed"
assert "Safari" in result, "Safari should be parsed"
assert "Chrome" in result, "Chrome should be parsed"

# Verify Safari aggregation (two processes combined)
safari_in, safari_out = result["Safari"]
assert safari_in == 12345678 + 11111111, f"Safari bytes_in should be aggregated"
assert safari_out == 9876543 + 2222222, f"Safari bytes_out should be aggregated"

print("\n✅ All tests passed! CSV parsing is working correctly.")
