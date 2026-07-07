import os
import re
import shutil

def map_modules_to_files(input_dir):
  
    module_to_file = {}
    file_to_modules = {}
    module_regex = re.compile(r'\bmodule\s+(\w+)', re.MULTILINE)

    for root, dirs, files in os.walk(input_dir):
        dirs[:] = [d for d in dirs if not d.endswith('_Merge')]
        for file in files:
            if file.lower().endswith(('.v', '.sv')):
                file_path = os.path.join(root, file)
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    
                    # Giữ nguyên số dòng khi xóa comment
                    def preserve_newlines(match):
                        return '\n' * match.group(0).count('\n')
                    
                    content = re.sub(r'/\*.*?\*/', preserve_newlines, content, flags=re.DOTALL)
                    content = re.sub(r'//.*', '', content)
                    
                    matches = module_regex.findall(content)
                    if matches:
                        file_to_modules[file_path] = []
                    
                    for mod_name in matches:
                        module_to_file[mod_name] = file_path
                        file_to_modules[file_path].append(mod_name)
                        
    return module_to_file, file_to_modules

def find_submodules(file_path, exclude_keywords):
    """
    Tìm module con và TRẢ VỀ CẢ SỐ DÒNG
    Format trả về: { 'Tên_Module_Con': [dòng_1, dòng_2, ...] }
    """
    submodules = {}
    if not file_path or not os.path.exists(file_path):
        return submodules

    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
        
        # Hàm giữ lại dấu xuống dòng để không làm lệch Line Number
        def preserve_newlines(match):
            return '\n' * match.group(0).count('\n')
            
        content_no_comments = re.sub(r'/\*.*?\*/', preserve_newlines, content, flags=re.DOTALL)
        content_no_comments = re.sub(r'//.*', '', content_no_comments)

        inst_regex = re.compile(r'\b([a-zA-Z_]\w*)\s+[a-zA-Z_]\w*\s*\(')
        
        for match in inst_regex.finditer(content_no_comments):
            mod_name = match.group(1)
            if mod_name not in exclude_keywords:
                # Tính toán số dòng bằng cách đếm số ký tự \n từ đầu file đến vị trí match
                line_no = content_no_comments.count('\n', 0, match.start()) + 1
                
                if mod_name not in submodules:
                    submodules[mod_name] = []
                submodules[mod_name].append(line_no)
                
    return submodules

def merge_digital_top_hierarchy(input_dir, top_module_name):
    verilog_keywords = {
        'always', 'initial', 'assign', 'module', 'endmodule', 'generate', 'endgenerate',
        'if', 'else', 'case', 'endcase', 'forever', 'repeat', 'while', 'for',
        'and', 'or', 'xor', 'nand', 'nor', 'xnor', 'not', 'buf'
    }

    print("1. Đang quét và lập bản đồ các module...")
    mod_file_map, file_mod_map = map_modules_to_files(input_dir)
    
    if top_module_name not in mod_file_map:
        print(f"❌ Lỗi: Không tìm thấy module gốc '{top_module_name}'!")
        return

    top_file_path = mod_file_map[top_module_name]
    _, ext = os.path.splitext(top_file_path)
    
    output_dir = os.path.join(input_dir, f"{top_module_name}_Merge")
    submodules_dir = os.path.join(output_dir, "Submodules_Copy")
    output_file = os.path.join(output_dir, f"{top_module_name}_Merged{ext}")

    os.makedirs(submodules_dir, exist_ok=True)

    modules_to_process = [top_module_name]
    visited_files = set()
    files_to_merge = []
    
    # 🌟 TỪ ĐIỂN LƯU TRỮ VỊ TRÍ INSTANTIATION (KÈM DÒNG)
    # Format: { 'SubMod': { 'ParentMod1': [line1, line2] } }
    instantiated_in = {}

    print(f"2. Bắt đầu phân tích phân cấp từ: {top_module_name}...")
    while modules_to_process:
        current_mod = modules_to_process.pop(0)
        current_file = mod_file_map.get(current_mod)
        
        if current_file and current_file not in visited_files:
            visited_files.add(current_file)
            files_to_merge.insert(0, current_file)
            
            subs_with_lines = find_submodules(current_file, verilog_keywords)
            for sub, lines in subs_with_lines.items():
                if sub not in instantiated_in:
                    instantiated_in[sub] = {}
                if current_mod not in instantiated_in[sub]:
                    instantiated_in[sub][current_mod] = []
                instantiated_in[sub][current_mod].extend(lines)
                
                if sub in mod_file_map and sub not in visited_files:
                    modules_to_process.append(sub)

    with open(output_file, 'w', encoding='utf-8') as outfile:
        outfile.write("// ==========================================================\n")
        outfile.write(f"// FILE TỔNG HỢP CÓ KIỂM DUYỆT CỦA: {top_module_name}\n")
        outfile.write("// ==========================================================\n\n")

    print(f"\n3. TIẾN HÀNH GOM VÀ COPY (Tổng cộng {len(files_to_merge)} file)")
    print("-" * 65)
    
    for file_path in files_to_merge:
        filename = os.path.basename(file_path)
        
        # 🌟 TẠO CHUỖI HIỂN THỊ MODULE CHA VÀ SỐ DÒNG
        parents_info_list = []
        modules_in_this_file = file_mod_map.get(file_path, [])
        for mod in modules_in_this_file:
            if mod in instantiated_in:
                for parent, lines in instantiated_in[mod].items():
                    # Sắp xếp số dòng và xóa trùng lặp
                    lines_str = ", ".join(f"dòng {l}" for l in sorted(set(lines)))
                    parents_info_list.append(f"{parent} ({lines_str})")
                    
        if file_path == top_file_path:
            parent_info = "🌟 ĐÂY LÀ MODULE GỐC (TOP)"
        else:
            parent_info = f"🔗 Gọi tại module: {'; '.join(parents_info_list)}"

        is_memory_file = any(keyword in filename.lower() for keyword in ['ram_', 'bram_', 'mem_'])
        
        if is_memory_file:
            print(f"\n🧠 THÔNG BÁO: Phát hiện submodule BỘ NHỚ: {filename}")
            print(f"   📂 Nguồn: {file_path}")
            print(f"   {parent_info}")
            
            while True:
                choice = input(f"   👉 Đưa file này ra thư mục gốc (không gộp)? [y/n/q]: ").strip().lower()
                if choice in ['y', 'n', 'q']: break
                print("   Vui lòng chỉ nhập 'y', 'n', hoặc 'q'.")
                
            if choice == 'q': return
            elif choice == 'n':
                print(f"   ⏭️  Đã BỎ QUA: {filename}")
                continue
            elif choice == 'y':
                try:
                    shutil.copy2(file_path, os.path.join(output_dir, filename))
                    print(f"   ✅ Đã COPY thành công ra thư mục gốc.")
                except Exception as e:
                    print(f"   ❌ Lỗi: {e}")
                continue 
                
        else:
            print(f"\n🔍 Đang chờ duyệt file LOGIC: {filename}")
            print(f"   📂 Nguồn: {file_path}")
            print(f"   {parent_info}")
            
            while True:
                choice = input("   👉 Bạn muốn Gộp & Copy file này? [y/n/q]: ").strip().lower()
                if choice in ['y', 'n', 'q']: break
                print("   Vui lòng chỉ nhập 'y', 'n', hoặc 'q'.")
                
            if choice == 'q': return
            if choice == 'n':
                print(f"   ⏭️  Đã BỎ QUA: {filename}")
                continue
                
            try:
                shutil.copy2(file_path, os.path.join(submodules_dir, filename))
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as infile:
                    content = infile.read()
                    content = re.sub(r'^\s*`include\s+".+"', r'// \g<0> (Đã tắt do gom file)', content, flags=re.MULTILINE)
                
                with open(output_file, 'a', encoding='utf-8') as outfile:
                    outfile.write(f"// --- START FILE: {filename} ---\n")
                    outfile.write(content)
                    outfile.write(f"\n// --- END FILE: {filename} ---\n\n")
                    
                print(f"   ✅ Đã GỘP thành công: {filename}")
                
            except Exception as e:
                print(f"   ❌ Lỗi: {e}")

    print("-" * 65)
    print(f"🎉 Hoàn tất!")

if __name__ == "__main__":
    SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
    
    INPUT_DIR = SCRIPT_DIR       
    TOP_MODULE = "PeripheryBus_cbus"     
    
    merge_digital_top_hierarchy(INPUT_DIR, TOP_MODULE)