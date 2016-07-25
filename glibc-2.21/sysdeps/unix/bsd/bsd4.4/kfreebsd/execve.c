int __syscall_execve(const char *filename, 
                     char *const argv[], 
                     char *const envp[]);
libc_hidden_proto (__syscall_execve)
#include <sysdeps/unix/sysv/linux/execve.c>
