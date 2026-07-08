import os
import re
import shutil

def map_modules_to_files(input_dir):
    module_to_file = {}
    file_to_modules = {}
    module_regex = re.compile(r'\bmodule\s+(\w+)', re.MULTILINE)

    for root, dirs, files in os.walk(input_dir):
        # Bỏ qua kho lưu trữ rác
        dirs[:] = [d for d in dirs if d != 'rm_dir']
        
        for file in files:
            # Không quét chính các file đã được Merged
            if file.lower().endswith(('.v', '.sv')) and not file.endswith('_Merged.v') and not file.endswith('_Merged.sv'):
                file_path = os.path.join(root, file)
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    
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
    submodules = {}
    if not file_path or not os.path.exists(file_path):
        return submodules

    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
        
        def preserve_newlines(match):
            return '\n' * match.group(0).count('\n')
            
        content_no_comments = re.sub(r'/\*.*?\*/', preserve_newlines, content, flags=re.DOTALL)
        content_no_comments = re.sub(r'//.*', '', content_no_comments)

        inst_regex = re.compile(r'\b([a-zA-Z_]\w*)\s+[a-zA-Z_]\w*\s*\(')
        
        for match in inst_regex.finditer(content_no_comments):
            mod_name = match.group(1)
            if mod_name not in exclude_keywords:
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
    
    # --- CẤU TRÚC THƯ MỤC ---
    output_dir = input_dir  
    output_file = os.path.join(output_dir, f"{top_module_name}_Merged{ext}")
    
    rm_dir = os.path.join(input_dir, "rm_dir")
    submodules_dir = os.path.join(rm_dir, f"submodule_{top_module_name}")
    os.makedirs(submodules_dir, exist_ok=True)

    modules_to_process = [top_module_name]
    visited_files = set()
    files_to_merge = []
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

    # TẬP HỢP THEO DÕI MODULE ĐÃ ĐƯỢC GỘP
    merged_module_names = set()

    print(f"\n3. TIẾN HÀNH GOM (Tổng cộng {len(files_to_merge)} file)")
    print("-" * 65)
    
    for file_path in files_to_merge:
        filename = os.path.basename(file_path)
        
        parents_info_list = []
        modules_in_this_file = file_mod_map.get(file_path, [])
        for mod in modules_in_this_file:
            if mod in instantiated_in:
                for parent, lines in instantiated_in[mod].items():
                    lines_str = ", ".join(f"dòng {l}" for l in sorted(set(lines)))
                    parents_info_list.append(f"{parent} ({lines_str})")
                    
        if file_path == top_file_path:
            parent_info = "🌟 ĐÂY LÀ MODULE GỐC (TOP)"
        else:
            parent_info = f"🔗 Gọi tại module: {'; '.join(parents_info_list)}"

        is_memory_file = any(keyword in filename.lower() for keyword in ['ram_', 'bram_', 'mem_'])
        
        if is_memory_file:
            print(f"\n🧠 BỘ NHỚ: Phát hiện submodule: {filename}")
            print(f"   📂 Nguồn: {file_path}")
            print(f"   {parent_info}")
            while True:
                choice = input(f"   👉 Di chuyển file này ra thư mục hiện tại (Không gộp)? [y/n/q]: ").strip().lower()
                if choice in ['y', 'n', 'q']: break
                
            if choice == 'q': 
                print("\n🛑 Dừng quá trình hỏi duyệt!"); break
            elif choice == 'n': continue
            elif choice == 'y':
                target_mem_path = os.path.join(output_dir, filename)
                if os.path.abspath(file_path) != os.path.abspath(target_mem_path):
                    shutil.move(file_path, target_mem_path)
                    print(f"   ✅ Đã di chuyển ra thư mục hiện tại.")
                else:
                    print(f"   ✅ File {filename} đã nằm sẵn ở thư mục hiện tại.")
                continue 
                
        else:
            print(f"\n🔍 LOGIC: Đang chờ duyệt file: {filename}")
            print(f"   📂 Nguồn: {file_path}")
            print(f"   {parent_info}")
            while True:
                choice = input("   👉 Bạn muốn Gộp file này? [y/n/q]: ").strip().lower()
                if choice in ['y', 'n', 'q']: break
                
            if choice == 'q': 
                print("\n🛑 Dừng quá trình hỏi duyệt!"); break
            if choice == 'n': continue
                
            try:
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as infile:
                    content = infile.read()
                    content = re.sub(r'^\s*`include\s+".+"', r'// \g<0> (Đã tắt do gom file)', content, flags=re.MULTILINE)
                
                with open(output_file, 'a', encoding='utf-8') as outfile:
                    outfile.write(f"// --- BẮT ĐẦU FILE: {filename} ---\n")
                    outfile.write(content)
                    outfile.write(f"\n// --- KẾT THÚC FILE: {filename} ---\n\n")
                    
                merged_module_names.update(modules_in_this_file)
                print(f"   ✅ Đã GỘP thành công!")
                
            except Exception as e:
                print(f"   ❌ Lỗi: {e}")

    # =====================================================================
    # BƯỚC 4: DỌN DẸP WORKSPACE & GHI NHẬN FILE BỊ DI CHUYỂN
    # =====================================================================
    print("\n" + "=" * 65)
    print("4. DỌN DẸP WORKSPACE (Tìm & Cất đi các file/module trùng lặp)")
    print("=" * 65)
    
    moved_count = 0
    moved_to_rm_dir = set() # DANH SÁCH LƯU CÁC FILE ĐÃ ĐƯỢC CHUYỂN VÀO KHO
    
    for f_path, mods in file_mod_map.items():
        intersect = set(mods).intersection(merged_module_names)
        
        if intersect:
            fname = os.path.basename(f_path)
            target_path = os.path.join(submodules_dir, fname)
            
            if os.path.exists(target_path) and os.path.abspath(f_path) != os.path.abspath(target_path):
                base, ext = os.path.splitext(fname)
                target_path = os.path.join(submodules_dir, f"{base}_dup_{moved_count}{ext}")
            
            if os.path.exists(f_path) and os.path.abspath(f_path) != os.path.abspath(target_path):
                try:
                    shutil.move(f_path, target_path)
                    moved_to_rm_dir.add(fname) # Ghi chú file này đã bị cất
                    print(f" 🧹 Đã di chuyển: {fname}")
                    moved_count += 1
                except Exception as e:
                    print(f" ❌ Lỗi di chuyển {fname}: {e}")

    # =====================================================================
    # BƯỚC 5: CẬP NHẬT FILELIST.F
    # =====================================================================
    filelist_path = os.path.join(input_dir, "filelist.f")
    if os.path.exists(filelist_path) and moved_to_rm_dir:
        print("\n" + "=" * 65)
        print("5. CẬP NHẬT TRẠNG THÁI TRONG FILELIST.F")
        print("=" * 65)
        
        try:
            with open(filelist_path, 'r', encoding='utf-8') as fl:
                lines = fl.readlines()
                
            new_lines = []
            updated_count = 0
            
            for line in lines:
                clean_line = line.strip()
                # Bỏ qua dòng trống hoặc những dòng đã bị comment hoàn toàn
                if not clean_line or clean_line.startswith('//'):
                    new_lines.append(line)
                    continue
                    
                # Lấy tên file từ đường dẫn trong filelist (loại bỏ phần comment phía sau nếu có)
                path_part = clean_line.split('//')[0].strip()
                fname = os.path.basename(path_part)
                
                # Nếu file này nằm trong danh sách đã bị cất đi và chưa có tag "đã gom"
                if fname in moved_to_rm_dir and "đã gom" not in line:
                    # Loại bỏ ký tự xuống dòng ở cuối (dù là \n hay \r\n), sau đó gắn chuỗi vào
                    new_lines.append(line.rstrip('\r\n') + " // đã gom\n")
                    updated_count += 1
                    print(f" 📝 Đánh dấu trong filelist: {fname}")
                else:
                    new_lines.append(line)
                    
            with open(filelist_path, 'w', encoding='utf-8') as fl:
                fl.writelines(new_lines)
                
            print(f" ✅ Đã cập nhật trạng thái 'đã gom' cho {updated_count} file!")
        except Exception as e:
            print(f" ❌ Lỗi cập nhật filelist.f: {e}")

    print("-" * 65)
    print(f"🎉 Hoàn tất toàn bộ quy trình!")
    print(f" 📄 File tổng hợp RTL sẵn sàng biên dịch: {output_file}")
    if moved_count > 0:
        print(f" 📂 Đã cất {moved_count} file gốc/trùng lặp vào: {submodules_dir}")

if __name__ == "__main__":
    SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
    INPUT_DIR = SCRIPT_DIR       
    TOP_MODULE = "DigitalTop"     
    
    merge_digital_top_hierarchy(INPUT_DIR, TOP_MODULE)