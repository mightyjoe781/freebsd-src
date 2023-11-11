import os
import queue
import subprocess
import threading
import time
import psutil

def recursive_kill(process):
    parent = psutil.Process(process.pid)
    for child in parent.children(recursive=True):
        child.kill()
    parent.kill()

# The producer function to populate the task queue
def produce_tasks(scripts, task_queue):
    for script in scripts:
        task_queue.put(script)

# The worker function to consume tasks from the queue
def consume_tasks(task_queue, timeout, counters):
    while True:
        try:
            script = task_queue.get(timeout=2)
            log_file = f"../runs/{script.split('/')[-1].replace('.sh', '.txt')}"
            start = time.time()
            process = subprocess.Popen(['/bin/sh', script], stdout=open(log_file, "w"), stderr=subprocess.STDOUT, shell=False)
            process.communicate(timeout=timeout)  # Execute the task
            els_time = time.time() - start
            # check if process was success or not
            if process.returncode == 0:
                print(f"{script.split('/')[-1]} success in {els_time:.2f}s")
                counters['passed'] += 1
            else:
                print(f"{script.split('/')[-1]} failed in {els_time:.2f}s")
                counters['failed'] += 1
            task_queue.task_done()  # Signaling task completion
        except subprocess.TimeoutExpired:
            recursive_kill(process)
            els_time = time.time() - start
            print(f"{script.split('/')[-1]} timed out in {els_time:.2f}s")
            counters['timeout'] += 1
            with open(log_file, 'w') as log:
                log.write("\n---Script execution timed out---\n")
        except queue.Empty:
            # print(f"Worker {threading.current_thread().name} has no task to execute")
            break  # No tasks left, exit loop


cpu_cores = psutil.cpu_count(logical=True)  # Physical CPU cores
available_memory = psutil.virtual_memory().available  # Available memory in bytes
print(f"Cores: {cpu_cores}")
print(f"Memory: {int(available_memory/(1024*1024))}MB")

# 75% of available memory
mem_threshold = 0.75 * available_memory
# Maximum workers based on available memory (if each worker takes a maximum of 512MB)
max_workers = min(cpu_cores, int(mem_threshold / (512 * 1024 * 1024)))  # Convert bytes to MB
# Number of worker threads
# max_workers = 5
timeout = 60  # Timeout for each worker in seconds

# List of scripts/tasks to be processed
root_dir = os.path.expanduser("~")+"/stand-test-root/scripts/"
dirs = ["amd64", "arm64-aarch64", "arm-armv7", "riscv-riscv64"]
scripts = []

for directory in dirs:
    script_dir = root_dir + directory + "/"
    files = os.listdir(script_dir)
    for file in files:
        scripts.append(script_dir + file)

if not os.path.exists('../runs'):
    os.makedirs('../runs')

print(f"{len(scripts)} scripts scheduled.")
print(f"Workers: {max_workers}")
print(f"Timeout: {timeout}s")

# Create a queue to hold the tasks
task_queue = queue.Queue()

# Start producer to populate tasks
producer_thread = threading.Thread(target=produce_tasks, args=(scripts, task_queue))
producer_thread.start()

# Start worker threads to consume tasks
worker_threads = []
# python dic are referenced :)
counters = {
    'passed' : 0,
    'failed' : 0,
    'timeout': 0,
}
start_time = time.time()
current_file = ['']
for i in range(max_workers):
    worker = threading.Thread(target=consume_tasks, args=(task_queue, timeout, counters), name=f"Worker-{i+1}")
    worker.start()
    worker_threads.append(worker)

# Wait for the producer to finish populating tasks
producer_thread.join()

# Wait for all tasks to be processed
for worker in worker_threads:
    worker.join()


elapsed_time = time.time() - start_time

print(f"Total Time Elapsed: {elapsed_time:.2f}s")
print("\nSummary : \n{} Passed\n{} Failed".format(counters['passed'], counters['failed'] + counters['timeout']))
