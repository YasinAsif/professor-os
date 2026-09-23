# CS301: Advanced Operating Systems
## Lecture 04: Process Synchronization, Classical Problems & Deadlock Handling
**Department of Computer Science & Software Engineering**

---

## 1. The Critical-Section Problem

In concurrent computing, cooperating processes share system resources or memory address spaces. When multiple processes execute concurrently, concurrent access to shared data may result in data inconsistency.

### 1.1 Requirements for Critical Section Solution
A valid solution to the critical-section problem must satisfy three essential criteria:

1. **Mutual Exclusion**: If process $P_i$ is executing in its critical section, no other processes can execute in their critical sections.
2. **Progress**: If no process is executing in its critical section and some processes wish to enter, only those processes not executing in their remainder sections can participate in deciding who enters next. Selection cannot be postponed indefinitely.
3. **Bounded Waiting**: There must exist a bound on the number of times other processes are allowed to enter their critical sections after a process has made a request to enter and before that request is granted.

---

## 2. Synchronization Primitives: Mutex & Semaphores

### 2.1 Mutex Locks
A mutex (mutual exclusion) lock is the simplest synchronization tool. A process must acquire the lock before entering a critical section and release it upon exit.
- `acquire()`: Atomically tests and sets lock flag. If locked, process busy-waits (spinlock).
- `release()`: Atomically unsets lock flag.

### 2.2 Semaphores
A semaphore $S$ is an integer variable that, apart from initialization, is accessed only through two standard atomic operations: `wait()` (traditionally $P$) and `signal()` (traditionally $V$).

```c
// Atomic wait operation (P)
void wait(Semaphore *S) {
    S->value--;
    if (S->value < 0) {
        add this process to S->queue;
        block();
    }
}

// Atomic signal operation (V)
void signal(Semaphore *S) {
    S->value++;
    if (S->value <= 0) {
        remove process P from S->queue;
        wakeup(P);
    }
}
```

* **Counting Semaphore**: Value ranges over an unrestricted domain, used to control access to a finite set of resources.
* **Binary Semaphore**: Value ranges between $0$ and $1$. Functions identically to a mutex lock.

---

## 3. Classical Synchronization Problems

### 3.1 The Producer-Consumer Problem (Bounded Buffer)
Producers produce items into a fixed-capacity buffer of size $N$; consumers consume them.
- Mutex semaphore `mutex` initialized to $1$ (protects buffer array).
- Counting semaphore `empty` initialized to $N$ (counts empty slots).
- Counting semaphore `full` initialized to $0$ (counts occupied slots).

```c
// Producer Code
do {
    // Produce an item in next_produced
    wait(&empty);
    wait(&mutex);
    // Add next_produced to buffer
    signal(&mutex);
    signal(&full);
} while (true);

// Consumer Code
do {
    wait(&full);
    wait(&mutex);
    // Remove item from buffer to next_consumed
    signal(&mutex);
    signal(&empty);
    // Consume item
} while (true);
```

### 3.2 The Dining-Philosophers Problem
Five philosophers spend their lives thinking and eating around a circular table with 5 chopsticks. A philosopher needs both adjacent chopsticks (left and right) to eat.
- **Naïve solution**: Each philosopher picks left, then right. Result: **Deadlock** if all 5 pick left simultaneously!
- **Deadlock-Free Solution**: Asymmetric ordering (odd philosophers pick left first, even pick right first) or state monitoring via monitor primitives (`THINKING`, `HUNGRY`, `EATING`).

---

## 4. Deadlock Characterization & Handling

A deadlock occurs when a set of blocked processes each holds a resource and waits to acquire a resource held by another process in the set.

### 4.1 The Four Necessary Conditions (Coffman Conditions)
Deadlock can arise if and only if all four conditions hold simultaneously:
1. **Mutual Exclusion**: At least one resource is held in a non-shareable mode.
2. **Hold and Wait**: A process must hold at least one resource and wait to acquire additional resources held by other processes.
3. **No Preemption**: Resources cannot be preempted; a resource can be released only voluntarily by the process holding it after completion.
4. **Circular Wait**: A closed chain of processes exists such that each process holds at least one resource needed by the next process in the chain ($P_0 \rightarrow P_1 \rightarrow \dots \rightarrow P_n \rightarrow P_0$).

### 4.2 The Banker's Algorithm for Deadlock Avoidance
Devised by Edsger Dijkstra, the Banker's algorithm tests for safety by simulating the allocation for predetermined maximum possible amounts of all resources, and then makes an "s-state" check to test for possible activities before deciding whether allocation should be allowed to continue.

* **Vectors & Matrices**:
  - `Available[m]`: Number of available units of each resource type.
  - `Max[n][m]`: Maximum demand of each process.
  - `Allocation[n][m]`: Amount currently allocated to each process.
  - `Need[n][m]`: Remaining resource need: $\text{Need}[i][j] = \text{Max}[i][j] - \text{Allocation}[i][j]$.

* **Safety Algorithm**:
  1. Let `Work = Available` and `Finish[i] = false` for all $i$.
  2. Find an index $i$ such that: `Finish[i] == false` and `Need[i] <= Work`. If no such $i$ exists, go to Step 4.
  3. `Work = Work + Allocation[i]`, `Finish[i] = true`. Go to Step 2.
  4. If `Finish[i] == true` for all $i$, the system is in a **Safe State**.
