import os
import re

lib_dir = r"C:\Users\ksonp\Downloads\Cozy Corner\study_library\lib"

# 1. Map all dart files: filename -> relative path from lib
file_map = {}
for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            abs_path = os.path.join(root, file)
            rel_to_lib = os.path.relpath(abs_path, lib_dir).replace('\\', '/')
            file_map[file] = rel_to_lib

# 2. Process all files
import_regex = re.compile(r"^(.*import\s+['\"])([^'\"]+)(['\"].*)$")

for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            file_path = os.path.join(root, file)
            with open(file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
            
            changed = False
            for i, line in enumerate(lines):
                match = import_regex.match(line)
                if match:
                    prefix = match.group(1)
                    import_path = match.group(2)
                    suffix = match.group(3)
                    
                    if import_path.startswith('.'):
                        # It's a relative import
                        resolved_abs = os.path.normpath(os.path.join(root, import_path))
                        
                        # Check if it exists
                        if os.path.exists(resolved_abs):
                            # It exists. If it uses ../, let's convert to package: import to be clean
                            if '../' in import_path:
                                rel_to_lib = os.path.relpath(resolved_abs, lib_dir).replace('\\', '/')
                                new_import = f"package:study_library/{rel_to_lib}"
                                lines[i] = f"{prefix}{new_import}{suffix}\n"
                                changed = True
                        else:
                            # It does NOT exist. Fix it using file_map.
                            basename = os.path.basename(import_path)
                            if basename in file_map:
                                new_import = f"package:study_library/{file_map[basename]}"
                                lines[i] = f"{prefix}{new_import}{suffix}\n"
                                changed = True
                                print(f"Fixed broken import in {os.path.relpath(file_path, lib_dir)}: {import_path} -> {new_import}")
                            else:
                                print(f"Could not find replacement for {basename} in {os.path.relpath(file_path, lib_dir)}")
                                # Let's also check if it's missing '.dart' extension (some people do that, though rare in dart)

            if changed:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.writelines(lines)

print("Import fixing complete.")
