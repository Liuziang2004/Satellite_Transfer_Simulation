function Satellite_Transfer_Simulation
clc; close all;

%% =========================
% 单卫星变轨演示器
% 初始轨道：GEO 同步圆轨道
% 目标轨道：多种圆轨道
% 变轨方式：共面霍曼转移
%% =========================

%% 常量
mu = 398600.4418;          % km^3/s^2
Re = 6378.137;             % km
T_sidereal = 86164.0905;   % s，恒星日
omegaEarth = 2*pi / T_sidereal;
orbitSampleNum = 720;

% 视野基准
baseAxisLim = 100000;
zoomFactor = 0.70;
currentAxisLim = baseAxisLim * zoomFactor;

% 时间流速
speedFactors = [9600, 4800, 2400];

%% 初始轨道：GEO
T_geo = T_sidereal;
a_geo = period2a(T_geo, mu);

%% 目标轨道集合
targetPeriodsHr = [4, 6, 8, 12, 18, 36, 48, 72];
targetPeriodsSec = targetPeriodsHr * 3600;
targetA = arrayfun(@(T) period2a(T, mu), targetPeriodsSec);

targetNames = cell(1, numel(targetPeriodsHr));
for k = 1:numel(targetPeriodsHr)
    targetNames{k} = sprintf('%d 小时圆轨道', targetPeriodsHr(k));
end

%% 状态变量
simTime = 0;
wallClock = tic;
lastWall = toc(wallClock);

% 当前卫星真正所在轨道
activeOrbit = makeCircularOrbit(a_geo, 0, simTime);

% "当前轨道"显示线：在转移时保留原圆轨道
currentCircularOrbit = activeOrbit;

% 默认目标轨道：12h
targetIdx = find(targetPeriodsHr == 12, 1, 'first');
if isempty(targetIdx)
    targetIdx = 1;
end
targetOrbit = makeCircularOrbit(targetA(targetIdx), 0, simTime);

% 转移相关
transferOrbit = [];
transferPreview = [];
pendingTransfer = false;
pendingCircularize = false;
transferBurnTime = NaN;
circularizeBurnTime = NaN;
firstBurnTheta = NaN;

% Δv
dv1 = 0;
dv2 = 0;

%% 图形界面
fig = figure( ...
    'Name', '卫星变轨演示器', ...
    'NumberTitle', 'off', ...
    'Color', 'k', ...
    'Position', [80, 60, 1600, 940]);

ax = axes('Parent', fig, 'Position', [0.05 0.08 0.68 0.86]);
hold(ax, 'on');
axis(ax, 'equal');
axis(ax, currentAxisLim * [-1 1 -1 1 -1 1]);
grid(ax, 'on');
set(ax, 'Color', 'k', ...
    'XColor', [0.85 0.85 0.85], ...
    'YColor', [0.85 0.85 0.85], ...
    'ZColor', [0.85 0.85 0.85], ...
    'GridColor', [0.35 0.35 0.35], ...
    'GridAlpha', 0.3);

xlabel(ax, 'X / km', 'Color', 'w');
ylabel(ax, 'Y / km', 'Color', 'w');
zlabel(ax, 'Z / km', 'Color', 'w');
titleHandle = title(ax, '卫星变轨演示器', 'Color', 'w', 'FontSize', 16);

%% 地球与贴图
earthGroup = hgtransform('Parent', ax);
[xe, ye, ze] = sphere(360);

scriptDir = fileparts(mfilename('fullpath'));
earthFile = fullfile(scriptDir, 'world.200401.3x5400x2700_geo.tif');

try
    earthImg = imread(earthFile);
    if ndims(earthImg) == 3 && size(earthImg,3) >= 3
        earthImg = earthImg(:,:,1:3);
    else
        error('贴图不是标准 RGB 图像。');
    end
    earthImg = flipud(earthImg);

    surf(ax, Re*xe, Re*ye, Re*ze, ...
        'Parent', earthGroup, ...
        'CData', earthImg, ...
        'FaceColor', 'texturemap', ...
        'EdgeColor', 'none', ...
        'FaceLighting', 'gouraud', ...
        'AmbientStrength', 0.45, ...
        'DiffuseStrength', 0.75, ...
        'SpecularStrength', 0.12);
catch ME
    warning('地球贴图读取失败：%s', ME.message);
    try
        load topo topo topomap1
        surf(ax, Re*xe, Re*ye, Re*ze, flipud(topo), ...
            'Parent', earthGroup, ...
            'FaceColor', 'texturemap', ...
            'EdgeColor', 'none', ...
            'FaceLighting', 'gouraud', ...
            'AmbientStrength', 0.45, ...
            'DiffuseStrength', 0.75, ...
            'SpecularStrength', 0.12);
        colormap(ax, topomap1);
    catch
        surf(ax, Re*xe, Re*ye, Re*ze, ...
            'Parent', earthGroup, ...
            'FaceColor', [0.08 0.25 0.65], ...
            'EdgeColor', 'none', ...
            'FaceLighting', 'gouraud', ...
            'AmbientStrength', 0.35, ...
            'DiffuseStrength', 0.7, ...
            'SpecularStrength', 0.15);
    end
end

material(ax, 'dull');
camlight(ax, 'headlight');
camlight(ax, 'right');

% 赤道线
th = linspace(0, 2*pi, 500);
plot3(ax, Re*cos(th), Re*sin(th), zeros(size(th)), '--', ...
    'Parent', earthGroup, ...
    'Color', [0.75 0.75 0.75], 'LineWidth', 0.8);

%% 控制面板
panel = uipanel( ...
    'Parent', fig, ...
    'Title', '控制面板', ...
    'FontSize', 11, ...
    'ForegroundColor', 'w', ...
    'BackgroundColor', [0.12 0.12 0.12], ...
    'Position', [0.76 0.05 0.22 0.90]);

uicontrol(panel, 'Style', 'text', ...
    'String', '目标轨道', ...
    'Units', 'normalized', ...
    'Position', [0.08 0.94 0.84 0.03], ...
    'BackgroundColor', [0.12 0.12 0.12], ...
    'ForegroundColor', 'w', ...
    'FontSize', 11, ...
    'FontWeight', 'bold', ...
    'HorizontalAlignment', 'left');

orbitPopup = uicontrol(panel, ...
    'Style', 'popupmenu', ...
    'String', targetNames, ...
    'Value', targetIdx, ...
    'Units', 'normalized', ...
    'Position', [0.08 0.90 0.84 0.04], ...
    'BackgroundColor', 'w', ...
    'ForegroundColor', 'k', ...
    'FontSize', 10, ...
    'Callback', @(~,~)onTargetChanged());

uicontrol(panel, 'Style', 'text', ...
    'String', '第一次脉冲模式', ...
    'Units', 'normalized', ...
    'Position', [0.08 0.84 0.84 0.03], ...
    'BackgroundColor', [0.12 0.12 0.12], ...
    'ForegroundColor', 'w', ...
    'FontSize', 11, ...
    'FontWeight', 'bold', ...
    'HorizontalAlignment', 'left');

burnModePopup = uicontrol(panel, ...
    'Style', 'popupmenu', ...
    'String', {'立即在当前位置执行', '等待到 +X 切点执行'}, ...
    'Value', 1, ...
    'Units', 'normalized', ...
    'Position', [0.08 0.80 0.84 0.04], ...
    'BackgroundColor', 'w', ...
    'ForegroundColor', 'k', ...
    'FontSize', 10);

btnTransfer = uicontrol(panel, ...
    'Style', 'pushbutton', ...
    'String', '进入椭圆轨道', ...
    'Units', 'normalized', ...
    'Position', [0.08 0.74 0.84 0.05], ...
    'BackgroundColor', 'w', ...
    'ForegroundColor', 'k', ...
    'FontSize', 10, ...
    'Callback', @(~,~)onEnterTransfer());

btnTarget = uicontrol(panel, ...
    'Style', 'pushbutton', ...
    'String', '进入目标轨道', ...
    'Units', 'normalized', ...
    'Position', [0.08 0.67 0.84 0.05], ...
    'BackgroundColor', 'w', ...
    'ForegroundColor', 'k', ...
    'FontSize', 10, ...
    'Callback', @(~,~)onEnterTarget());

uicontrol(panel, 'Style', 'text', ...
    'String', '时间流速', ...
    'Units', 'normalized', ...
    'Position', [0.08 0.61 0.84 0.03], ...
    'BackgroundColor', [0.12 0.12 0.12], ...
    'ForegroundColor', 'w', ...
    'FontSize', 11, ...
    'FontWeight', 'bold', ...
    'HorizontalAlignment', 'left');

speedPopup = uicontrol(panel, ...
    'Style', 'popupmenu', ...
    'String', {'高 9600×', '中 4800×', '低 2400×'}, ...
    'Value', 1, ...
    'Units', 'normalized', ...
    'Position', [0.08 0.57 0.84 0.04], ...
    'BackgroundColor', 'w', ...
    'ForegroundColor', 'k', ...
    'FontSize', 10);

uicontrol(panel, 'Style', 'text', ...
    'String', '视角', ...
    'Units', 'normalized', ...
    'Position', [0.08 0.51 0.84 0.03], ...
    'BackgroundColor', [0.12 0.12 0.12], ...
    'ForegroundColor', 'w', ...
    'FontSize', 11, ...
    'FontWeight', 'bold', ...
    'HorizontalAlignment', 'left');

viewPopup = uicontrol(panel, ...
    'Style', 'popupmenu', ...
    'String', {'默认视角', '俯视视角'}, ...
    'Value', 1, ...
    'Units', 'normalized', ...
    'Position', [0.08 0.47 0.84 0.04], ...
    'BackgroundColor', 'w', ...
    'ForegroundColor', 'k', ...
    'FontSize', 10, ...
    'Callback', @(~,~)applyView());

uicontrol(panel, 'Style', 'text', ...
    'String', '缩放', ...
    'Units', 'normalized', ...
    'Position', [0.08 0.41 0.84 0.03], ...
    'BackgroundColor', [0.12 0.12 0.12], ...
    'ForegroundColor', 'w', ...
    'FontSize', 11, ...
    'FontWeight', 'bold', ...
    'HorizontalAlignment', 'left');

zoomLabel = uicontrol(panel, ...
    'Style', 'text', ...
    'String', sprintf('%.2f × 视野', zoomFactor), ...
    'Units', 'normalized', ...
    'Position', [0.08 0.38 0.84 0.025], ...
    'BackgroundColor', [0.12 0.12 0.12], ...
    'ForegroundColor', [0.92 0.92 0.92], ...
    'FontSize', 9.5, ...
    'HorizontalAlignment', 'left');

zoomSlider = uicontrol(panel, ...
    'Style', 'slider', ...
    'Min', 0.20, ...
    'Max', 1.50, ...
    'Value', zoomFactor, ...
    'Units', 'normalized', ...
    'Position', [0.08 0.34 0.84 0.035], ...
    'Callback', @(~,~)applyZoom());

infoText = uicontrol(panel, ...
    'Style', 'text', ...
    'String', '', ...
    'Units', 'normalized', ...
    'Position', [0.08 0.04 0.84 0.27], ...
    'BackgroundColor', [0.12 0.12 0.12], ...
    'ForegroundColor', [0.92 0.92 0.92], ...
    'FontSize', 9.5, ...
    'HorizontalAlignment', 'left');

%% 图形对象
hCurrent = plot3(ax, NaN, NaN, NaN, '-', ...
    'Color', [0.20 1.00 0.20], 'LineWidth', 1.8);
hTarget = plot3(ax, NaN, NaN, NaN, '-', ...
    'Color', [0.20 0.75 1.00], 'LineWidth', 1.8);
hTransfer = plot3(ax, NaN, NaN, NaN, '--', ...
    'Color', [1.00 0.75 0.20], 'LineWidth', 1.8);

hSat = plot3(ax, NaN, NaN, NaN, 'o', ...
    'MarkerSize', 9, ...
    'MarkerFaceColor', [1.0 0.3 0.3], ...
    'MarkerEdgeColor', 'w');

legend(ax, [hCurrent, hTarget, hTransfer], ...
    {'当前轨道', '目标轨道', '转移椭圆轨道'}, ...
    'TextColor', 'w', ...
    'Color', 'k', ...
    'Location', 'southoutside');

applyDefaultView();
updateButtons();
updateScene();

%% 主循环
while ishandle(fig)
    currentWall = toc(wallClock);
    wallDt = currentWall - lastWall;
    lastWall = currentWall;

    speedFactor = speedFactors(get(speedPopup, 'Value'));
    dtFrame = speedFactor * wallDt;
    remainingDt = dtFrame;

    while remainingDt > 0
        nextEventTime = inf;
        eventType = 0;

        if pendingTransfer && transferBurnTime < nextEventTime
            nextEventTime = transferBurnTime;
            eventType = 1;
        end

        if pendingCircularize && circularizeBurnTime < nextEventTime
            nextEventTime = circularizeBurnTime;
            eventType = 2;
        end

        if nextEventTime <= simTime + 1e-12
            if eventType == 1
                performFirstBurn(nextEventTime);
            elseif eventType == 2
                performSecondBurn(nextEventTime);
            end
            continue;
        end

        if simTime + remainingDt >= nextEventTime
            dt1 = nextEventTime - simTime;
            simTime = simTime + dt1;
            remainingDt = remainingDt - dt1;

            if eventType == 1
                performFirstBurn(nextEventTime);
            elseif eventType == 2
                performSecondBurn(nextEventTime);
            end
        else
            simTime = simTime + remainingDt;
            remainingDt = 0;
        end
    end

    updateScene();
    drawnow limitrate;
end

%% =========================
% 嵌套函数
%% =========================

    function onTargetChanged()
        if pendingTransfer || activeOrbit.e > 1e-10
            set(orbitPopup, 'Value', targetIdx);
            return;
        end
        targetIdx = get(orbitPopup, 'Value');
        targetOrbit = makeCircularOrbit(targetA(targetIdx), 0, simTime);
        dv1 = 0;
        dv2 = 0;
        updateButtons();
        updateScene();
    end

    function onEnterTransfer()
        if pendingTransfer || activeOrbit.e > 1e-10
            return;
        end

        targetIdx = get(orbitPopup, 'Value');
        targetOrbit = makeCircularOrbit(targetA(targetIdx), 0, simTime);

        if abs(activeOrbit.a - targetOrbit.a) < 1e-6
            return;
        end

        currentCircularOrbit = activeOrbit;
        [dv1, dv2] = hohmannDeltaV(currentCircularOrbit.a, targetOrbit.a, mu);

        burnMode = get(burnModePopup, 'Value');

        if burnMode == 1
            % 立即在当前位置执行第一次脉冲
            [~, ~, thetaNow] = getStateECI(activeOrbit, simTime, mu);
            firstBurnTheta = thetaNow;
            transferOrbit = makeTransferOrbit(currentCircularOrbit.a, targetOrbit.a, firstBurnTheta, simTime, mu);
            activeOrbit = transferOrbit;

            pendingTransfer = false;
            pendingCircularize = false;
            transferBurnTime = NaN;
            circularizeBurnTime = NaN;
            transferPreview = [];
        else
            % 等待到 +X 切点执行第一次脉冲
            firstBurnTheta = 0;
            transferPreview = makeTransferOrbit(currentCircularOrbit.a, targetOrbit.a, firstBurnTheta, simTime, mu);
            transferBurnTime = getNextThetaTime(currentCircularOrbit, simTime, firstBurnTheta, mu);
            pendingTransfer = true;
            pendingCircularize = false;
            circularizeBurnTime = NaN;
            transferOrbit = [];
        end

        updateButtons();
        updateScene();
    end

    function onEnterTarget()
        if pendingTransfer
            return;
        end
        if activeOrbit.e <= 1e-10
            return;
        end
        if pendingCircularize
            return;
        end

        pendingCircularize = true;
        circularizeBurnTime = getNextCircularizeTime(simTime, activeOrbit);
        updateButtons();
        updateScene();
    end

    function performFirstBurn(tBurn)
        transferOrbit = makeTransferOrbit(currentCircularOrbit.a, targetOrbit.a, firstBurnTheta, tBurn, mu);
        activeOrbit = transferOrbit;
        pendingTransfer = false;
        transferBurnTime = NaN;
        transferPreview = [];
        updateButtons();
    end

    function performSecondBurn(tBurn)
        [~, ~, thetaBurn] = getStateECI(activeOrbit, tBurn, mu);
        activeOrbit = makeCircularOrbit(targetOrbit.a, thetaBurn, tBurn);
        currentCircularOrbit = activeOrbit;
        targetOrbit = makeCircularOrbit(targetA(targetIdx), 0, simTime);

        transferOrbit = [];
        transferPreview = [];
        pendingCircularize = false;
        circularizeBurnTime = NaN;

        updateButtons();
    end

    function updateButtons()
        if pendingTransfer
            set(btnTransfer, 'Enable', 'off');
            set(btnTarget, 'Enable', 'off');
            set(orbitPopup, 'Enable', 'off');
            set(burnModePopup, 'Enable', 'off');
        elseif activeOrbit.e > 1e-10
            set(btnTransfer, 'Enable', 'off');
            set(orbitPopup, 'Enable', 'off');
            set(burnModePopup, 'Enable', 'off');
            if pendingCircularize
                set(btnTarget, 'Enable', 'off');
            else
                set(btnTarget, 'Enable', 'on');
            end
        else
            set(orbitPopup, 'Enable', 'on');
            set(burnModePopup, 'Enable', 'on');
            set(btnTarget, 'Enable', 'off');

            if abs(activeOrbit.a - targetA(get(orbitPopup, 'Value'))) < 1e-6
                set(btnTransfer, 'Enable', 'off');
            else
                set(btnTransfer, 'Enable', 'on');
            end
        end
    end

    function updateScene()
        % 地球旋转
        thetaEarth = omegaEarth * simTime;
        earthGroup.Matrix = makehgtform('zrotate', thetaEarth);

        % 卫星位置
        [rSat, ~, ~] = getStateECI(activeOrbit, simTime, mu);
        set(hSat, 'XData', rSat(1), 'YData', rSat(2), 'ZData', rSat(3));

        % 阶段文字
        if pendingTransfer
            phaseName = '等待第一次脉冲';
        elseif activeOrbit.e > 1e-10
            if pendingCircularize
                phaseName = '等待第二次脉冲';
            else
                phaseName = '转移椭圆轨道';
            end
        else
            phaseName = '当前圆轨道';
        end

        % 三条轨道线
        if pendingTransfer
            xyzCurrent = getOrbitXYZ(currentCircularOrbit, orbitSampleNum);
            xyzTarget = getOrbitXYZ(targetOrbit, orbitSampleNum);
            xyzTransfer = getOrbitXYZ(transferPreview, orbitSampleNum);

            set(hCurrent, 'XData', xyzCurrent(1,:), 'YData', xyzCurrent(2,:), 'ZData', xyzCurrent(3,:), 'Visible', 'on');
            set(hTarget, 'XData', xyzTarget(1,:), 'YData', xyzTarget(2,:), 'ZData', xyzTarget(3,:), 'Visible', 'on');
            set(hTransfer, 'XData', xyzTransfer(1,:), 'YData', xyzTransfer(2,:), 'ZData', xyzTransfer(3,:), 'Visible', 'on');

        elseif activeOrbit.e > 1e-10
            xyzCurrent = getOrbitXYZ(currentCircularOrbit, orbitSampleNum);
            xyzTarget = getOrbitXYZ(targetOrbit, orbitSampleNum);
            xyzTransfer = getOrbitXYZ(activeOrbit, orbitSampleNum);

            set(hCurrent, 'XData', xyzCurrent(1,:), 'YData', xyzCurrent(2,:), 'ZData', xyzCurrent(3,:), 'Visible', 'on');
            set(hTarget, 'XData', xyzTarget(1,:), 'YData', xyzTarget(2,:), 'ZData', xyzTarget(3,:), 'Visible', 'on');
            set(hTransfer, 'XData', xyzTransfer(1,:), 'YData', xyzTransfer(2,:), 'ZData', xyzTransfer(3,:), 'Visible', 'on');

        else
            xyzCurrent = getOrbitXYZ(activeOrbit, orbitSampleNum);
            set(hCurrent, 'XData', xyzCurrent(1,:), 'YData', xyzCurrent(2,:), 'ZData', xyzCurrent(3,:), 'Visible', 'on');

            if abs(activeOrbit.a - targetA(targetIdx)) > 1e-6
                xyzTarget = getOrbitXYZ(targetOrbit, orbitSampleNum);

                burnMode = get(burnModePopup, 'Value');
                if burnMode == 1
                    % 当前位置执行模式：预览椭圆轨道跟着卫星一起转
                    [~, ~, thetaNow] = getStateECI(activeOrbit, simTime, mu);
                    previewTheta = thetaNow;
                else
                    % 等待切点模式：预览椭圆轨道固定在 +X 切点
                    previewTheta = 0;
                end

                transferPreviewLocal = makeTransferOrbit(activeOrbit.a, targetOrbit.a, previewTheta, simTime, mu);
                xyzTransfer = getOrbitXYZ(transferPreviewLocal, orbitSampleNum);

                set(hTarget, 'XData', xyzTarget(1,:), 'YData', xyzTarget(2,:), 'ZData', xyzTarget(3,:), 'Visible', 'on');
                set(hTransfer, 'XData', xyzTransfer(1,:), 'YData', xyzTransfer(2,:), 'ZData', xyzTransfer(3,:), 'Visible', 'on');
            else
                set(hTarget, 'XData', NaN, 'YData', NaN, 'ZData', NaN, 'Visible', 'off');
                set(hTransfer, 'XData', NaN, 'YData', NaN, 'ZData', NaN, 'Visible', 'off');
            end
        end

        % 信息文字
        currentPeriodHr = a2period(currentCircularOrbit.a, mu) / 3600;
        targetPeriodHr = targetPeriodsHr(targetIdx);

        explain1 = '第一次脉冲：把卫星从当前圆轨道送入转移椭圆轨道。';
        explain2 = '第二次脉冲：在另一切点圆化，进入目标圆轨道。';

        if pendingTransfer
            wait1 = max(0, transferBurnTime - simTime);
            infoStr = sprintf([ ...
                '阶段：%s\n\n' ...
                '当前轨道半长轴：%.1f km\n' ...
                '当前轨道周期：%.3f h\n\n' ...
                '目标轨道半长轴：%.1f km\n' ...
                '目标轨道周期：%.3f h\n\n' ...
                '第一次脉冲 Δv：%+.4f km/s\n' ...
                '第二次脉冲 Δv：%+.4f km/s\n\n' ...
                '%s\n%s\n\n' ...
                '第一次脉冲剩余等待：%.1f s'], ...
                phaseName, ...
                currentCircularOrbit.a, currentPeriodHr, ...
                targetOrbit.a, targetPeriodHr, ...
                dv1, dv2, explain1, explain2, wait1);

        elseif activeOrbit.e > 1e-10
            transferPeriodHr = a2period(activeOrbit.a, mu) / 3600;
            if pendingCircularize
                wait2 = max(0, circularizeBurnTime - simTime);
                waitText = sprintf('第二次脉冲剩余等待：%.1f s', wait2);
            else
                waitText = '第二次脉冲：等待点击按钮';
            end

            infoStr = sprintf([ ...
                '阶段：%s\n\n' ...
                '当前圆轨道半长轴：%.1f km\n' ...
                '当前圆轨道周期：%.3f h\n\n' ...
                '目标轨道半长轴：%.1f km\n' ...
                '目标轨道周期：%.3f h\n\n' ...
                '转移椭圆半长轴：%.1f km\n' ...
                '转移椭圆偏心率：%.5f\n' ...
                '转移椭圆周期：%.3f h\n\n' ...
                '第一次脉冲 Δv：%+.4f km/s\n' ...
                '第二次脉冲 Δv：%+.4f km/s\n\n' ...
                '%s\n%s\n\n' ...
                '%s'], ...
                phaseName, ...
                currentCircularOrbit.a, currentPeriodHr, ...
                targetOrbit.a, targetPeriodHr, ...
                activeOrbit.a, activeOrbit.e, transferPeriodHr, ...
                dv1, dv2, explain1, explain2, waitText);

        else
            infoStr = sprintf([ ...
                '阶段：%s\n\n' ...
                '当前轨道半长轴：%.1f km\n' ...
                '当前轨道周期：%.3f h\n\n' ...
                '目标轨道半长轴：%.1f km\n' ...
                '目标轨道周期：%.3f h\n\n' ...
                '第一次脉冲 Δv：%+.4f km/s\n' ...
                '第二次脉冲 Δv：%+.4f km/s\n\n' ...
                '%s\n%s'], ...
                phaseName, ...
                activeOrbit.a, a2period(activeOrbit.a, mu)/3600, ...
                targetOrbit.a, targetPeriodHr, ...
                dv1, dv2, explain1, explain2);
        end

        set(infoText, 'String', infoStr);
        set(titleHandle, 'String', sprintf('卫星变轨演示器  |  t = %.3f h', simTime/3600));

        applyView();
    end

    function applyZoom()
        zoomFactor = get(zoomSlider, 'Value');
        currentAxisLim = baseAxisLim * zoomFactor;
        axis(ax, currentAxisLim * [-1 1 -1 1 -1 1]);
        set(zoomLabel, 'String', sprintf('%.2f × 视野', zoomFactor));
        applyView();
    end

    function applyView()
        mode = get(viewPopup, 'Value');
        switch mode
            case 1
                applyDefaultView();
            case 2
                camtarget(ax, [0 0 0]);
                campos(ax, [0 0 currentAxisLim*2.2]);
                camup(ax, [0 1 0]);
                camproj(ax, 'orthographic');
        end
    end

    function applyDefaultView()
        camtarget(ax, [0 0 0]);
        campos(ax, currentAxisLim * [1.35 1.00 0.75]);
        camup(ax, [0 0 1]);
        camproj(ax, 'orthographic');
    end

%% =========================
% 数学辅助函数
%% =========================

    function orbit = makeCircularOrbit(a, theta0, t0)
        orbit.a = a;
        orbit.e = 0;
        orbit.i = 0;
        orbit.raan = 0;
        orbit.argp = 0;
        orbit.M0 = wrap2pi_local(theta0);
        orbit.t0 = t0;
        orbit.fullPeriod = a2period(a, mu);
    end

    function orbit = makeTransferOrbit(r1, r2, thetaBurn, t0, muValue)
        orbit.a = (r1 + r2)/2;
        orbit.e = abs(r2 - r1) / (r1 + r2);
        orbit.i = 0;
        orbit.raan = 0;

        if r2 >= r1
            nuBurn = 0;
            orbit.argp = wrap2pi_local(thetaBurn);
        else
            nuBurn = pi;
            orbit.argp = wrap2pi_local(thetaBurn - pi);
        end

        orbit.M0 = true2mean(nuBurn, orbit.e);
        orbit.t0 = t0;
        orbit.fullPeriod = a2period(orbit.a, muValue);
        orbit.halfPeriod = orbit.fullPeriod / 2;
    end

    function [r_eci, nu, theta] = getStateECI(orbit, t, muValue)
        n = sqrt(muValue / orbit.a^3);
        M = wrap2pi_local(orbit.M0 + n * (t - orbit.t0));

        if orbit.e < 1e-12
            E = M;
            nu = M;
        else
            E = solveKepler_local(M, orbit.e);
            nu = 2 * atan2( sqrt(1+orbit.e)*sin(E/2), sqrt(1-orbit.e)*cos(E/2) );
            nu = wrap2pi_local(nu);
        end

        rmag = orbit.a * (1 - orbit.e*cos(E));
        r_pf = [rmag*cos(nu); rmag*sin(nu); 0];
        Q = rotz_local(orbit.raan) * rotx_local(orbit.i) * rotz_local(orbit.argp);
        r_eci = Q * r_pf;
        theta = wrap2pi_local(atan2(r_eci(2), r_eci(1)));
    end

    function xyz = getOrbitXYZ(orbit, numPoints)
        nuVec = linspace(0, 2*pi, numPoints);
        xyz = zeros(3, numPoints);
        Q = rotz_local(orbit.raan) * rotx_local(orbit.i) * rotz_local(orbit.argp);
        for m = 1:numPoints
            nu = nuVec(m);
            r = orbit.a * (1 - orbit.e^2) / (1 + orbit.e*cos(nu));
            r_pf = [r*cos(nu); r*sin(nu); 0];
            xyz(:,m) = Q * r_pf;
        end
    end

    function [dvFirst, dvSecond] = hohmannDeltaV(r1, r2, muValue)
        aT = (r1 + r2)/2;
        v1 = sqrt(muValue / r1);
        v2 = sqrt(muValue / r2);
        vT1 = sqrt(muValue * (2/r1 - 1/aT));
        vT2 = sqrt(muValue * (2/r2 - 1/aT));
        dvFirst = vT1 - v1;
        dvSecond = v2 - vT2;
    end

    function tBurn = getNextThetaTime(circleOrbit, tNow, thetaTarget, muValue)
        [~, ~, thetaNow] = getStateECI(circleOrbit, tNow, muValue);
        n = sqrt(muValue / circleOrbit.a^3);
        deltaTheta = wrap2pi_local(thetaTarget - thetaNow);
        tBurn = tNow + deltaTheta / n;
    end

    function tBurn = getNextCircularizeTime(tNow, orbit)
        firstTime = orbit.t0 + orbit.halfPeriod;
        if tNow <= firstTime
            tBurn = firstTime;
        else
            k = ceil((tNow - firstTime) / orbit.fullPeriod);
            tBurn = firstTime + k * orbit.fullPeriod;
        end
    end

    function a = period2a(T, muValue)
        a = (muValue * (T/(2*pi))^2)^(1/3);
    end

    function T = a2period(a, muValue)
        T = 2*pi * sqrt(a^3 / muValue);
    end

    function M = true2mean(nu, e)
        if e < 1e-12
            M = wrap2pi_local(nu);
            return;
        end
        E = 2 * atan2( sqrt(1-e)*sin(nu/2), sqrt(1+e)*cos(nu/2) );
        M = wrap2pi_local(E - e*sin(E));
    end

    function E = solveKepler_local(M, e)
        E = M;
        for it = 1:40
            f  = E - e*sin(E) - M;
            fp = 1 - e*cos(E);
            dE = -f / fp;
            E = E + dE;
            if abs(dE) < 1e-12
                break;
            end
        end
    end

    function R = rotx_local(a_deg)
        a = deg2rad(a_deg);
        R = [1 0 0;
             0 cos(a) -sin(a);
             0 sin(a)  cos(a)];
    end

    function R = rotz_local(a_deg)
        a = deg2rad(a_deg);
        R = [cos(a) -sin(a) 0;
             sin(a)  cos(a) 0;
             0       0      1];
    end

    function x = wrap2pi_local(x)
        x = mod(x, 2*pi);
        if x < 0
            x = x + 2*pi;
        end
    end

end