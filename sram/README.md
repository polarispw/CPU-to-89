# 双发射五级流水CPU-SRAM func test

## 关于双发测试的一些必要改动

1.64bits指令读入：

用`docs`里的`coe_scipt.cpp`把测试包里的`func_test_v0.01/soft/func/obj/inst_ram.coe`改写（`docs`里的`out.coe`是改写好的可以直接用），然后在项目里进行如下设置

<img src="docs\Cache_1610e1857761cfd.jpg" style="zoom:67%;" />

<img src="docs\Cache_2c77917c2a68f406.jpg" style="zoom:50%;" />

<img src="docs\Cache_4d2fe7ef86e0ed68.jpg" style="zoom:80%;" />

2.调整取址相关线路的线宽：

`func_test_v0.01/soc_sram_func/rtl/soc_lite_top.v`文件中

```verilog
116	wire [63:0] cpu_inst_rdata;
168	.addra (cpu_inst_addr[19:3]),   //17:0
```

3.testbench相关内容：

写回段debug时在高低电平分别检测两条指令执行情况（`WB.v`已经修改过，不需要再改动，上板时不用这样双边检测）

同时修改test_bench的检测时机，从上沿改成电平检测

```verilog
123	always @(soc_clk)
139	always @(soc_clk)
240	always @(soc_clk)
```



## 关于设计逻辑

1. decoder只负责检查数据冲突，具体取操作数等判断完是否双发后再进行
1. 跳转指令的接收，和FIFO之间的检查，延迟槽的发射要重点考虑
1. bf4c9c4 CP0后跟跳转 如果跳转时直接重置fifo可能会导致EPC存不到错误地址
1. 跳转指令后紧跟例外指令时要注意
1. 要写回的跳转指令和会造成例外的延迟槽一同发射时会导致写回失败

## 关于对外接口



## 更新日志

7/19，CP0寄存器复写bug，改动CP0.v

7/24，整理优化线路
