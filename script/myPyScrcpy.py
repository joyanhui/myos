#!/usr/bin/env python3
import subprocess
import tkinter as tk
from tkinter import ttk, messagebox

ADB = "adb"
SCRCPY = "scrcpy"


class App:
    def __init__(self, root):
        self.root = root
        root.title("myPyScrcpy")
        root.geometry("480x360")
        self.procs = {}
        self.devices = []

        frame = ttk.Frame(root, padding=8)
        frame.pack(fill=tk.BOTH, expand=True)

        self.listbox = tk.Listbox(frame)
        self.listbox.pack(fill=tk.BOTH, expand=True, side=tk.LEFT)
        scroll = ttk.Scrollbar(frame, command=self.listbox.yview)
        scroll.pack(side=tk.RIGHT, fill=tk.Y)
        self.listbox.config(yscrollcommand=scroll.set)

        btns = ttk.Frame(root, padding=8)
        btns.pack(fill=tk.X)
        ttk.Button(btns, text="刷新设备", command=self.scan).pack(side=tk.LEFT)
        ttk.Button(btns, text="连接", command=self.connect).pack(side=tk.LEFT, padx=4)
        ttk.Button(btns, text="断开", command=self.disconnect).pack(side=tk.LEFT)
        ttk.Button(btns, text="退出", command=root.destroy).pack(side=tk.RIGHT)

        self.status = tk.Label(root, text="就绪", anchor=tk.W, padx=8)
        self.status.pack(fill=tk.X)

        self.scan()

    def scan(self):
        try:
            out = subprocess.run([ADB, "devices"], capture_output=True, text=True, timeout=10).stdout
        except Exception as e:
            messagebox.showerror("错误", str(e))
            return
        self.devices = []
        self.listbox.delete(0, tk.END)
        for line in out.splitlines()[1:]:
            parts = line.strip().split()
            if len(parts) >= 2 and parts[1] == "device":
                self.devices.append(parts[0])
                self.listbox.insert(tk.END, parts[0])
        self.status.config(text=f"找到 {len(self.devices)} 个设备")

    def connect(self):
        sel = self.listbox.curselection()
        if not sel:
            messagebox.showinfo("提示", "请先选择设备")
            return
        serial = self.devices[sel[0]]
        p = self.procs.get(serial)
        if p and p.poll() is None:
            self.status.config(text=f"{serial} 已连接")
            return
        try:
            self.procs[serial] = subprocess.Popen([SCRCPY, "--serial", serial])
            self.status.config(text=f"正在连接 {serial}（scrcpy 窗口将出现）")
        except Exception as e:
            messagebox.showerror("错误", str(e))

    def disconnect(self):
        sel = self.listbox.curselection()
        if not sel:
            return
        serial = self.devices[sel[0]]
        p = self.procs.pop(serial, None)
        if p and p.poll() is None:
            p.terminate()
        self.status.config(text=f"已断开 {serial}")


if __name__ == "__main__":
    root = tk.Tk()
    App(root)
    root.mainloop()
