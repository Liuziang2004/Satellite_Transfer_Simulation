# Orbit Transfer Simulation Suite

# 轨道转移仿真程序集

This repository contains two MATLAB visualization programs. One is a single-satellite Hohmann transfer demonstrator starting from GEO and targeting multiple circular orbits. The other is an Earth–Moon mission-process simulator with selectable direction and mission style, step-by-step buttons, textured Earth and Moon, automatic camera behavior, and explanatory panels. 

本仓库包含两个 MATLAB 可视化仿真程序。第一个程序用于演示从 GEO 同步轨道出发、转移到多种圆轨道的共面霍曼变轨过程。第二个程序用于演示地球—月球任务过程，支持任务方向选择、任务风格选择、分步操作按钮、地球与月球贴图、自动镜头跟踪以及说明面板。 

## Files

## 文件说明

### `Satellite_Transfer_Simulation.m`

A single-satellite transfer demonstrator. The satellite starts from GEO and can transfer to several preset circular target orbits with periods of 4, 6, 8, 12, 18, 36, 48, and 72 hours. The transfer model is coplanar Hohmann transfer. The interface includes a target-orbit dropdown, transfer and target-entry buttons, time-speed control, view selection, zoom control, and an information panel.

单卫星变轨演示程序。卫星从 GEO 同步圆轨道出发，可以转移到若干预设目标圆轨道，目标周期包括 4、6、8、12、18、36、48、72 小时。变轨模型为共面霍曼转移。界面包含目标轨道下拉框、进入椭圆轨道与进入目标轨道按钮、时间流速控制、视角选择、缩放控制以及信息面板。

### `Earth_Moon_Transfer_Simulation.m`

An Earth–Moon mission-process simulator. It supports two mission directions, Earth → Moon and Moon → Earth, and uses a style catalog for different mission modes. The interface provides direction selection, style selection, four step buttons, reset, time-speed control, view selection, zoom control, mission summary text, and a 3D scene with Earth, Moon, transfer tracks, trail, and legend.

地月任务过程仿真程序。它支持两种任务方向，即“地球 → 月球”和“月球 → 地球”，并通过风格目录管理不同任务模式。界面提供任务方向选择、风格选择、四个分步按钮、重置任务、时间流速控制、视角选择、缩放控制、任务摘要文字，以及包含地球、月球、转移轨迹、飞行尾迹和图例的三维场景。

## Required Texture Files

## 贴图文件

Place the texture files in the same folder as the MATLAB scripts before running. The Earth texture file is `world.200401.3x5400x2700_geo.tif`. The Earth–Moon simulator also uses the Moon texture file `2k_moon.jpg`.

运行前请将贴图文件放在 MATLAB 脚本所在目录。地球贴图文件为 `world.200401.3x5400x2700_geo.tif`。地月仿真程序还需要月球贴图文件 `2k_moon.jpg`。

## Features

## 主要功能

### 1. GEO Hohmann Transfer Demonstrator

### 1. GEO 霍曼变轨演示器

* Starts from GEO circular orbit.

* Supports multiple preset circular target orbits.

* Displays current orbit, target orbit, and transfer ellipse.

* Supports staged transfer operation and event-based waiting for burns.

* Includes Earth texture rendering, speed control, view switching, zoom, and status text.

* 以 GEO 同步圆轨道为初始轨道。

* 支持多个预设目标圆轨道。

* 显示当前轨道、目标轨道和转移椭圆轨道。

* 支持分阶段变轨操作以及基于事件时刻的等待点火。

* 包含地球贴图、时间流速控制、视角切换、缩放和状态文字显示。

### 2. Earth–Moon Mission Simulator

### 2. 地月任务过程仿真器

* Supports both Earth → Moon and Moon → Earth directions.

* Supports multiple mission styles through a style catalog.

* Uses four step buttons to guide the mission process.

* Renders textured Earth and Moon in a 3D scene.

* Shows mission tracks, active orbit/segment, trail, and legend.

* Includes speed control, view control, zoom control, and mission explanation text.

* 支持“地球 → 月球”和“月球 → 地球”两种任务方向。

* 通过风格目录支持多种任务模式。

* 使用四个分步按钮引导任务过程。

* 在三维场景中渲染带贴图的地球与月球。

* 显示任务轨迹、当前驻留轨道或当前飞行段、飞行尾迹和图例。

* 包含时间流速控制、视角控制、缩放控制以及任务说明文字。

## How to Run

## 运行方法

### MATLAB

1. Put the `.m` files and required texture files in the same working folder.
2. Open MATLAB and change the current folder to that directory.
3. Run one of the following commands:

#### GEO transfer simulator

```matlab
Satellite_Transfer_Simulation
```

#### Earth–Moon mission simulator

```matlab
Earth_Moon_Transfer_Simulation
```

这两个程序都是 MATLAB 脚本函数形式。运行前请先把 `.m` 文件和贴图文件放到同一工作目录，然后在 MATLAB 中切换到该目录并执行对应函数。

## Controls

## 交互方式

### `Satellite_Transfer_Simulation.m`

Use the right-side panel to select the target orbit, trigger transfer, enter the target orbit, change time speed, switch view, and adjust zoom. The program also displays status and transfer information in the text panel.

使用右侧控制面板选择目标轨道、触发转移、进入目标轨道、调整时间流速、切换视角并控制缩放。程序还会在文字面板中显示当前状态和变轨信息。

### `Earth_Moon_Transfer_Simulation.m`

Use the right-side panel to select mission direction and mission style, then perform the mission step by step with the four step buttons. You can also reset the mission, change the simulation speed, switch camera view, and adjust zoom. The explanation area summarizes the current mission state and next action.

使用右侧控制面板选择任务方向和任务风格，然后通过四个分步按钮按阶段执行任务。你还可以重置任务、调整仿真速度、切换镜头视角并调节缩放。说明区域会总结当前任务状态以及下一步动作。

## Notes

## 说明

These programs are designed for visualization and teaching. The GEO simulator focuses on coplanar Hohmann transfer logic between circular orbits. The Earth–Moon simulator focuses on mission-process presentation and staged interaction rather than high-fidelity flight dynamics.

这两个程序主要面向可视化展示与教学演示。GEO 程序重点展示圆轨道之间的共面霍曼转移逻辑。地月程序重点展示任务过程、阶段推进和交互式说明，而不是高保真航天动力学求解。

## Recommended Folder Structure

## 建议目录结构

```text
project/
├─ Satellite_Transfer_Simulation.m
├─ Earth_Moon_Transfer_Simulation.m
├─ world.200401.3x5400x2700_geo.tif
└─ 2k_moon.jpg
```
