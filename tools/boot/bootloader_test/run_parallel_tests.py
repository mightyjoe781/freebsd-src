import os
import subprocess
from concurrent.futures import ThreadPoolExecutor
import psutil
import time

root_dir = "/root/stand-test-root/scripts/"
dirs = ["amd64", "arm64-aarch64", "arm-armv7", "riscv-riscv64"]
# dirs = ["arm64-aarch64"]
scripts = []

for directory in dirs:
    script_dir = root_dir + directory + "/"
    files = os.listdir(script_dir)
    for file in files:
        scripts.append(script_dir + file)

print(str(len(scripts)) + " scripts will run!")

if not os.path.exists('../runs'):
    os.makedirs('../runs')

passed = 0
failed = 0

start_time = time.time()

batch_size = 6
timeout = 60

def run_script(script):
    log_file = f"../runs/{script.split('/')[-1].replace('.sh', '.txt')}"
    process = subprocess.Popen(['/bin/sh', script], stdout=open(log_file, "w"), stderr=subprocess.STDOUT, shell=False)
    return process, log_file, time.time()

def recursive_kill(process):
    parent = psutil.Process(process.pid)
    for child in parent.children(recursive=True):
        child.kill()
    parent.kill()

with ThreadPoolExecutor(max_workers=batch_size) as executor:
    process_dict = {}  # Dictionary to keep track of running subprocesses
    for script in scripts[:batch_size]:
        process_dict[script] = run_script(script)
    scripts = scripts[batch_size:]

    while process_dict or scripts:
        for script, (process, log_file, start) in list(process_dict.items()):
            retcode = process.poll()

            # something happened to process
            if retcode is not None:
                if process.returncode == 0:
                    passed += 1
                    els_time = time.time()-start
                    print(f"{script.split('/')[-1]} success in {els_time:.2f}s")
                else:
                    failed += 1
                    els_time = time.time()-start
                    print(f"{script.split('/')[-1]} failed in {els_time:.2f}s")
                    with open(log_file, 'w') as log:
                        log.write(f"\n---Script failed with return code {process.returncode}---\n")
            # else we check time to kill process ?
            elif time.time() - start > timeout:
                recursive_kill(process)
                failed += 1
                els_time = time.time()-start
                print(f"{script.split('/')[-1]} timed out in {els_time:.2f}s")
                with open(log_file, 'w') as log:
                    log.write("\n---Script execution timed out---\n")
            else:
                # keep checking that list
                continue
            process_dict.pop(script)
            break

        for script in scripts:
            if len(process_dict) < batch_size:
                process_dict[script] = run_script(script)
                scripts.remove(script)
                break

elapsed_time = time.time() - start_time
if elapsed_time > 60:
    minutes, seconds = divmod(elapsed_time, 60)
    print(f"Time elapsed: {int(minutes)} minute(s) and {seconds:.2f} seconds")
else:
    print(f"Time elapsed: {elapsed_time:.2f} seconds")
print("\nSummary : \n{} Passed\n{} Failed".format(passed, failed))
