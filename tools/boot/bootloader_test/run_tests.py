import os
import subprocess
import psutil
from subprocess import DEVNULL, STDOUT

# we go in directory
root_dir = "/root/stand-test-root/scripts/"
dirs = ["amd64", "arm64-aarch64", "arm-armv7", "riscv-riscv64"]
scripts = []


for dir in dirs:
    script_dir = root_dir + dir + "/"
    # do ls in directory
    files = os.listdir(script_dir)
    for f in files:
        scripts.append(script_dir + f)
    
# scripts = scripts[:3]
print(str(len(scripts))+" scripts will run!")
passed = 0
failed = 0
for script in scripts:
    timeout = 60
    print(script + " running")
    # p = subprocess.Popen(['/bin/sh',script], shell=False, stdout=STDOUT, stderr=STDOUT)
    p = subprocess.Popen(['/bin/sh',script], shell=False, stdout=DEVNULL, stderr=STDOUT)
    try:
        p.wait(timeout)
        passed = passed + 1
        print(script + " success")
    except subprocess.TimeoutExpired:
        print(script + " failed")
        parent = psutil.Process(p.pid)
        for child in parent.children(recursive=True):
            child.kill()
        parent.kill()
        failed = failed + 1

print("\nSummary : \n{} Passed\n{} Failed".format(passed, failed))