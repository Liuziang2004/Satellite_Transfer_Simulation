
function Earth_Moon_Transfer_Simulation
clc; close all;

%% ===================== 常量 =====================
muE = 398600.4418;
muM = 4902.800066;
Re  = 6378.137;
Rm  = 1737.4;
Tsid = 86164.0905;
omegaEarth = 2*pi/Tsid;
Tmoon = 27.321661 * 86400;
omegaMoon = 2*pi/Tmoon;
aMoon = 384400;

rEarthPark = Re + 185;
rLunarPark = Rm + 110;
rApolloPeri = Rm + 120;
rApolloCaptureApo = Rm + 6000;
rFlybyPeri = Rm + 140;
rDRO = Rm + 15000;
rNRHORp = Rm + 3000;
rNRHORa = Rm + 9500;
rEntry = Re + 120;
rSplash = Re + 15;

baseAxisLim = 430000;
zoomMagnification = 1.50;
axisHalfSpan = baseAxisLim / zoomMagnification;

speedFactors = [900, 3600, 14400];
speedLabels = {'低 15 分钟/秒', '中 1 小时/秒', '高 4 小时/秒'};
orbitSamples = 720;
transferSamples = 900;
trailMax = 5000;
trailMinStep = 450;

%% ===================== 全局状态 =====================
directionList = {'地球 → 月球', '月球 → 地球'};
directionMode = 1;
styleList = getStyleCatalog(directionMode);
styleIndex = 1;
currentStyle = styleList(styleIndex);

moonPhase0 = 0;
simTime = 0;
clockRef = tic;
lastWall = toc(clockRef);
viewMode = 1;

mission = struct();
trailXYZ = nan(3,0);
lastTrailPoint = [nan; nan; nan];

%% ===================== 窗口与坐标轴 =====================
fig = figure('Name','地月转移过程仿真演示器', ...
    'NumberTitle','off', ...
    'Color','k', ...
    'Position',[40 30 1740 980], ...
    'Renderer','opengl');

ax = axes('Parent',fig,'Position',[0.045 0.07 0.69 0.87]);
hold(ax,'on');
axis(ax,'equal');
axis(ax, axisHalfSpan*[-1 1 -1 1 -1 1]);
set(ax,'Color','k', ...
    'XColor',[0.85 0.85 0.85], 'YColor',[0.85 0.85 0.85], 'ZColor',[0.85 0.85 0.85], ...
    'GridColor',[0.35 0.35 0.35], 'GridAlpha',0.22, 'Projection','perspective');
grid(ax,'on');
xlabel(ax,'X / km','Color','w');
ylabel(ax,'Y / km','Color','w');
zlabel(ax,'Z / km','Color','w');
hTitle = title(ax,'地月转移过程仿真演示器','Color','w','FontSize',16,'FontWeight','bold');

%% 星空
rng(7);
starCount = 1400;
starShell = 2.7*baseAxisLim;
theta = 2*pi*rand(starCount,1);
u = 2*rand(starCount,1)-1;
phi = acos(u);
r = starShell.*(0.88+0.12*rand(starCount,1));
sx = r.*sin(phi).*cos(theta);
sy = r.*sin(phi).*sin(theta);
sz = r.*cos(phi);
scatter3(ax,sx,sy,sz,1.2+5.5*(rand(starCount,1).^2),[1 1 1],'filled', ...
    'MarkerFaceAlpha',0.65,'MarkerEdgeAlpha',0.0,'HandleVisibility','off');

%% 贴图
scriptDir = fileparts(mfilename('fullpath'));
earthFile = fullfile(scriptDir,'world.200401.3x5400x2700_geo.tif');
moonFile  = fullfile(scriptDir,'2k_moon.jpg');

earthTranslate = hgtransform('Parent',ax);
earthRotate = hgtransform('Parent',earthTranslate);
moonTranslate = hgtransform('Parent',ax);
moonRotate = hgtransform('Parent',moonTranslate);

[xs,ys,zs] = sphere(220);
createTexturedBody(ax, earthRotate, Re, xs, ys, zs, earthFile, [0.10 0.28 0.70]);
createTexturedBody(ax, moonRotate,  Rm, xs, ys, zs, moonFile,  [0.62 0.62 0.65]);
material(ax,'dull');
camlight(ax,'headlight'); camlight(ax,'right'); camlight(ax,'left');

%% 图形对象
hMoonOrbit = plot3(ax, NaN, NaN, NaN, ':', 'Color', [0.62 0.62 0.62], 'LineWidth', 1.0);
hCurrent   = plot3(ax, NaN, NaN, NaN, '-',  'Color', [0.25 1.00 0.25], 'LineWidth', 1.8);
hTarget    = plot3(ax, NaN, NaN, NaN, '-',  'Color', [0.25 0.75 1.00], 'LineWidth', 1.8);
hTransfer  = plot3(ax, NaN, NaN, NaN, '--', 'Color', [1.00 0.78 0.22], 'LineWidth', 2.0);
hTrail     = plot3(ax, NaN, NaN, NaN, '-',  'Color', [1.00 1.00 1.00], 'LineWidth', 1.1);
hCraft     = plot3(ax, NaN, NaN, NaN, 'o', 'MarkerSize', 8.5, ...
    'MarkerFaceColor',[1.0 0.35 0.35], 'MarkerEdgeColor','w');
hSplash    = plot3(ax, NaN, NaN, NaN, 'p', 'MarkerSize', 12, ...
    'MarkerFaceColor',[1.00 0.87 0.18], 'MarkerEdgeColor','k', 'Visible','off');

legend(ax, [hMoonOrbit, hCurrent, hTarget, hTransfer, hTrail], ...
    {'月球公转轨道', '当前驻留轨道', '当前目标轨道 / 目标区域', '当前主动转移段 / 预示轨迹', '已飞行轨迹'}, ...
    'Location','northeast', 'TextColor','w', 'Color','k', 'AutoUpdate','off');

%% 右侧面板（带滑动栏）
panelOuter = uipanel('Parent',fig,'Title','控制与说明','FontSize',11,'ForegroundColor','w', ...
    'BackgroundColor',[0.12 0.12 0.12],'Position',[0.76 0.05 0.22 0.90]);
set(panelOuter,'Clipping','on');

contentHeight = 1.30;
panel = uipanel('Parent',panelOuter,'BorderType','none', ...
    'BackgroundColor',[0.12 0.12 0.12], 'Units','normalized', ...
    'Position',[0.00 1-contentHeight 0.94 contentHeight]);

scrollSlider = uicontrol(panelOuter,'Style','slider','Units','normalized', ...
    'Position',[0.95 0.02 0.035 0.96], 'Min',0,'Max',1,'Value',1, ...
    'SliderStep',[0.06 0.18], 'BackgroundColor',[0.16 0.16 0.16], ...
    'Callback',@(~,~)onScroll());

uicontrol(panel,'Style','text','String','控制栏','Units','normalized', ...
    'Position',[0.08 0.965 0.84 0.024], 'BackgroundColor',[0.12 0.12 0.12], ...
    'ForegroundColor',[1 1 1], 'FontSize',11.5,'FontWeight','bold','HorizontalAlignment','left');

uicontrol(panel,'Style','text','String','任务方向','Units','normalized', ...
    'Position',[0.08 0.930 0.84 0.024], 'BackgroundColor',[0.12 0.12 0.12], ...
    'ForegroundColor','w','FontSize',10.5,'FontWeight','bold','HorizontalAlignment','left');

directionPopup = uicontrol(panel,'Style','popupmenu','String',directionList,'Value',directionMode, ...
    'Units','normalized','Position',[0.08 0.894 0.84 0.035], ...
    'BackgroundColor','w','ForegroundColor','k','FontSize',10,'Callback',@(~,~)onDirectionChanged());

uicontrol(panel,'Style','text','String','风格选择','Units','normalized', ...
    'Position',[0.08 0.860 0.84 0.024], 'BackgroundColor',[0.12 0.12 0.12], ...
    'ForegroundColor','w','FontSize',10.5,'FontWeight','bold','HorizontalAlignment','left');

stylePopup = uicontrol(panel,'Style','popupmenu','String',{styleList.name},'Value',styleIndex, ...
    'Units','normalized','Position',[0.08 0.824 0.84 0.035], ...
    'BackgroundColor','w','ForegroundColor','k','FontSize',10,'Callback',@(~,~)onStyleChanged());

styleSummaryText = uicontrol(panel,'Style','text','String',currentStyle.summary, ...
    'Units','normalized','Position',[0.08 0.775 0.84 0.045], ...
    'BackgroundColor',[0.18 0.18 0.18], 'ForegroundColor',[0.96 0.96 0.96], ...
    'FontSize',9.6,'HorizontalAlignment','center');

uicontrol(panel,'Style','text','String','分步操作','Units','normalized', ...
    'Position',[0.08 0.735 0.84 0.024], 'BackgroundColor',[0.12 0.12 0.12], ...
    'ForegroundColor',[1 1 1], 'FontSize',11.0,'FontWeight','bold','HorizontalAlignment','left');

stepBtn(1) = uicontrol(panel,'Style','pushbutton','String','', 'Units','normalized', ...
    'Position',[0.08 0.684 0.84 0.042],'FontSize',10.0,'Callback',@(~,~)onStepPressed(1));
stepBtn(2) = uicontrol(panel,'Style','pushbutton','String','', 'Units','normalized', ...
    'Position',[0.08 0.636 0.84 0.042],'FontSize',10.0,'Callback',@(~,~)onStepPressed(2));
stepBtn(3) = uicontrol(panel,'Style','pushbutton','String','', 'Units','normalized', ...
    'Position',[0.08 0.588 0.84 0.042],'FontSize',10.0,'Callback',@(~,~)onStepPressed(3));
stepBtn(4) = uicontrol(panel,'Style','pushbutton','String','', 'Units','normalized', ...
    'Position',[0.08 0.540 0.84 0.042],'FontSize',10.0,'Callback',@(~,~)onStepPressed(4));

uicontrol(panel,'Style','pushbutton','String','重置任务','Units','normalized', ...
    'Position',[0.08 0.488 0.84 0.046],'FontSize',10.5,'BackgroundColor',[0.95 0.95 0.95], ...
    'Callback',@(~,~)resetMission(true));

uicontrol(panel,'Style','text','String','时间流速','Units','normalized', ...
    'Position',[0.08 0.447 0.84 0.024],'BackgroundColor',[0.12 0.12 0.12], ...
    'ForegroundColor','w','FontSize',10.5,'FontWeight','bold','HorizontalAlignment','left');

speedPopup = uicontrol(panel,'Style','popupmenu','String',speedLabels,'Value',2, ...
    'Units','normalized','Position',[0.08 0.412 0.84 0.035], ...
    'BackgroundColor','w','ForegroundColor','k','FontSize',10);

uicontrol(panel,'Style','text','String','视角','Units','normalized', ...
    'Position',[0.08 0.378 0.84 0.024],'BackgroundColor',[0.12 0.12 0.12], ...
    'ForegroundColor','w','FontSize',10.5,'FontWeight','bold','HorizontalAlignment','left');

uicontrol(panel,'Style','popupmenu', ...
    'String',{'默认视角','俯视视角','地月连线视角','跟随飞船视角'}, ...
    'Value',1,'Units','normalized','Position',[0.08 0.343 0.84 0.035], ...
    'BackgroundColor','w','ForegroundColor','k','FontSize',10, ...
    'Callback',@(~,~)applyViewSelection(), 'Tag','viewPopup');
viewPopup = findobj(panel,'Tag','viewPopup');

uicontrol(panel,'Style','text','String','缩放','Units','normalized', ...
    'Position',[0.08 0.309 0.84 0.024],'BackgroundColor',[0.12 0.12 0.12], ...
    'ForegroundColor','w','FontSize',10.5,'FontWeight','bold','HorizontalAlignment','left');

zoomLabel = uicontrol(panel,'Style','text', ...
    'String',sprintf('%s 倍放大', formatZoomMultiplier(zoomMagnification)), ...
    'Units','normalized','Position',[0.08 0.280 0.84 0.022], ...
    'BackgroundColor',[0.12 0.12 0.12],'ForegroundColor',[0.92 0.92 0.92], ...
    'FontSize',9.5,'HorizontalAlignment','left');

uicontrol(panel,'Style','slider','Min',1.00,'Max',20.00,'Value',zoomMagnification, ...
    'SliderStep',[0.05 0.15], 'Units','normalized','Position',[0.08 0.248 0.84 0.030], ...
    'Callback',@(~,~)applyZoom(), 'Tag','zoomSlider');
zoomSlider = findobj(panel,'Tag','zoomSlider');

uicontrol(panel,'Style','text','String','说明栏','Units','normalized', ...
    'Position',[0.08 0.214 0.84 0.024],'BackgroundColor',[0.12 0.12 0.12], ...
    'ForegroundColor',[1 1 1],'FontSize',11.5,'FontWeight','bold','HorizontalAlignment','left');

infoText = uicontrol(panel,'Style','text','String','', ...
    'Units','normalized','Position',[0.08 0.030 0.84 0.175], ...
    'BackgroundColor',[0.12 0.12 0.12], 'ForegroundColor',[0.92 0.92 0.92], ...
    'FontSize',9.1, 'HorizontalAlignment','left');

%% 初始化
applyDefaultView();
set(scrollSlider,'Value',1); onScroll();
resetMission(false);
updateScene();

%% 主循环
while ishandle(fig)
    currentWall = toc(clockRef);
    wallDt = currentWall - lastWall;
    lastWall = currentWall;

    speedFactor = speedFactors(get(speedPopup,'Value'));
    if mission.running
        advanceMissionClock(wallDt * speedFactor);
    end

    updateScene();
    drawnow limitrate;
end

%% ===================== 交互 =====================
    function onDirectionChanged()
        directionMode = get(directionPopup,'Value');
        styleList = getStyleCatalog(directionMode);
        styleIndex = 1;
        currentStyle = styleList(styleIndex);
        set(stylePopup,'String',{styleList.name},'Value',styleIndex);
        set(styleSummaryText,'String',currentStyle.summary);
        resetMission(true);
    end

    function onStyleChanged()
        styleIndex = get(stylePopup,'Value');
        currentStyle = styleList(styleIndex);
        set(styleSummaryText,'String',currentStyle.summary);
        resetMission(true);
    end

    function applyViewSelection()
        viewMode = get(viewPopup,'Value');
    end

    function applyZoom()
        zoomMagnification = get(zoomSlider,'Value');
        axisHalfSpan = baseAxisLim / zoomMagnification;
        set(zoomLabel,'String',sprintf('%s 倍放大', formatZoomMultiplier(zoomMagnification)));
    end

    function onScroll()
        val = get(scrollSlider,'Value');
        set(panel,'Position',[0.00 (1-contentHeight)*val 0.94 contentHeight]);
    end

    function resetMission(resetClock)
        if nargin < 1, resetClock = true; end
        if resetClock
            clockRef = tic;
            lastWall = toc(clockRef);
        end
        simTime = 0;
        moonPhase0 = 0;
        trailXYZ = nan(3,0);
        lastTrailPoint = [nan; nan; nan];
        set(hSplash,'Visible','off');
        if ishandle(scrollSlider), set(scrollSlider,'Value',1); onScroll(); end

        mission = struct();
        mission.style = currentStyle;
        mission.styleTag = currentStyle.tag;
        mission.summary = currentStyle.summary;
        mission.stepLabels = currentStyle.steps;
        mission.stepState = [1 0 0 0];
        mission.running = false;
        mission.completed = false;
        mission.activeSeg = makeIdlePoint([0;0;0]);
        mission.previewSeg = [];
        mission.targetSeg = [];
        mission.pending = struct('active',false,'time',NaN,'kind','none','segment',[]);
        mission.onActiveEnd = 'none';
        mission.phaseName = '待命';
        mission.orbitName = '尚未进入任务轨道';
        mission.nextAdvice = '先按下第一个按钮，建立当前风格的初始驻留轨道。';
        mission.detail = currentStyle.summary;
        mission.entryEndPoint = [nan; nan; nan];

        set(hTitle,'String',sprintf('地月转移过程仿真演示器｜%s｜%s', directionList{directionMode}, currentStyle.name));
        updateButtons();
        updateInfoText();
    end

    function onStepPressed(idx)
        if mission.stepState(idx) ~= 1
            return;
        end
        switch idx
            case 1
                pressStep1();
            case 2
                pressStep2();
            case 3
                pressStep3();
            case 4
                pressStep4();
        end
        updateButtons();
        updateInfoText();
        updateScene();
    end

    function pressStep1()
        mission.previewSeg = [];
        mission.targetSeg = [];
        mission.pending = struct('active',false,'time',NaN,'kind','none','segment',[]);
        mission.onActiveEnd = 'none';
        set(hSplash,'Visible','off');

        switch mission.styleTag
            case 'apollo_out'
                mission.activeSeg = makeEarthCircular(rEarthPark, 0, simTime, +1, '地球停泊轨道');
                setStatus('地球停泊轨道阶段', '近地停泊圆轨道', ...
                    '接下来按下 TLI。系统会先画出完整地月转移椭圆，再等飞船转到切点后执行点火。', ...
                    '此时只有当前地球停泊轨道会显示，不会提前泄露月球附近的后续轨道。');
            case 'artemis_out'
                mission.activeSeg = makeEarthCircular(rEarthPark, 0, simTime, +1, '地球停泊轨道');
                setStatus('地球停泊轨道阶段', '近地停泊圆轨道', ...
                    '接下来按下 TLI。先飞向近月飞越点，再做外向飞越。', ...
                    '这个风格不是先低月轨圆化，而是先进入"能做飞越"的位置。');
            case 'capstone_out'
                mission.activeSeg = makeEarthEllipsePeriodicGeneral(Re+300, 120000, 0, simTime, 0, +1, '地球远地点抬升轨道');
                setStatus('地球远地点抬升阶段', '高椭圆相位轨道', ...
                    '接下来按下 BLT 出发。系统会先画出低能转移通道，再等飞船回到近地点时离开地球。', ...
                    '这一风格强调先慢慢抬高远地点，再走更省推进剂的低能路径。');
            case 'apollo_in'
                mission.activeSeg = makeMoonCircular(rLunarPark, 0, simTime, +1, '低月轨');
                setStatus('低月轨待返阶段', '低月停泊圆轨道', ...
                    '接下来按下 TEI。系统会先画出返地转移，再等飞船到切点自动开始。', ...
                    '此时飞船围月连续运行；如果你不按下一步，地月系统会与飞船一起停住。');
            case 'artemis_in'
                mission.activeSeg = makeMoonCircular(rDRO, 0, simTime, -1, 'DRO');
                setStatus('DRO 驻留阶段', '远逆行轨道', ...
                    '接下来按下"离开 DRO"。系统会先画出离开 DRO 的过渡段，再等飞船到切点开始。', ...
                    '这一风格要先从 DRO 动力学系统里脱离，再进入返地几何。');
            case 'change5_in'
                mission.activeSeg = makeMoonCircular(rLunarPark, 0, simTime, +1, '月球返回准备轨道');
                setStatus('月球返回准备阶段', '低月停泊圆轨道', ...
                    '接下来按下 TEI。系统会先画出高速返地段，再等飞船到切点后离月。', ...
                    '这一风格后面的重点不是离月本身，而是高速再入怎么减能。');
        end

        mission.running = true;
        mission.stepState = [2 1 0 0];
    end

    function pressStep2()
        switch mission.styleTag
            case 'apollo_out'
                tBurn = solveApolloOutboundBurnTime(mission.activeSeg, simTime, rEarthPark, aMoon - rApolloPeri);
                seg = buildApolloOutboundTransfer(tBurn);
                guide = buildMoonWindowAtSegmentEnd(seg, 'LOI 窗口', 0.18*pi);
                armStep2('apollo_out_burn', tBurn, seg, guide, ...
                    '等待 TLI 切点', '仍在近地停泊圆轨道', ...
                    '地月转移椭圆已经完整画出。飞船继续绕地球飞行，到达切点后自动点火。', ...
                    sprintf('当前先展示完整的转移方式，真正点火要等飞船自己转到切点。预计等待 %s。', formatMissionTime(max(tBurn-simTime,0))));
            case 'artemis_out'
                tBurn = solveApolloOutboundBurnTime(mission.activeSeg, simTime, rEarthPark, aMoon - rFlybyPeri);
                seg = buildArtemisOutboundTransfer(tBurn);
                guide = buildMoonWindowAtSegmentEnd(seg, '近月飞越窗口', 0.20*pi);
                armStep2('artemis_out_burn', tBurn, seg, guide, ...
                    '等待 TLI 切点', '仍在近地停泊圆轨道', ...
                    '第一段地月转移已经完整画出。飞船继续绕地球飞行，到达切点后自动进入转移段。', ...
                    sprintf('先把过程讲清楚，再让飞船自己飞到执行窗口。预计等待 %s。', formatMissionTime(max(tBurn-simTime,0))));
            case 'capstone_out'
                tBurn = nextEarthPeriodicPeriapsis(mission.activeSeg, simTime);
                seg = buildCapstoneBLT(tBurn);
                armStep2('capstone_out_burn', tBurn, seg, [], ...
                    '等待 BLT 出发窗口', '仍在高椭圆相位轨道', ...
                    '低能转移通道已经完整画出。飞船继续绕地球运行，到近地点时自动进入 BLT。', ...
                    sprintf('BLT 不是一次猛踹，而是等飞船先回到近地点再顺势离开。预计等待 %s。', formatMissionTime(max(tBurn-simTime,0))));
            case 'apollo_in'
                tBurn = nextMoonLocalPhase(mission.activeSeg, simTime, 0);
                seg = buildApolloInboundReturn(tBurn);
                armStep2('apollo_in_burn', tBurn, seg, [], ...
                    '等待 TEI 切点', '仍在低月停泊圆轨道', ...
                    '返地椭圆已经完整画出。飞船继续绕月运行，到达切点时自动开始返地。', ...
                    sprintf('这里先把返回怎么走展示清楚，再等飞船自己飞到返程窗口。预计等待 %s。', formatMissionTime(max(tBurn-simTime,0))));
            case 'artemis_in'
                tBurn = nextMoonLocalPhase(mission.activeSeg, simTime, 0);
                seg = buildArtemisDepartDRO(tBurn);
                armStep2('artemis_in_burn', tBurn, seg, [], ...
                    '等待离开 DRO 切点', '仍在 DRO', ...
                    '离开 DRO 的过渡段已经画出。飞船到达切点后自动开始离开 DRO。', ...
                    sprintf('这一步不是直接回地球，而是先从 DRO 系统里脱离。预计等待 %s。', formatMissionTime(max(tBurn-simTime,0))));
            case 'change5_in'
                tBurn = nextMoonLocalPhase(mission.activeSeg, simTime, 0);
                seg = buildChange5Return(tBurn);
                armStep2('change5_in_burn', tBurn, seg, [], ...
                    '等待 TEI 切点', '仍在月球返回准备轨道', ...
                    '高速返地弧段已经画出。飞船到切点后自动开始返地。', ...
                    sprintf('这里先展示返地怎么走，真正离月仍然要等飞船转到切点。预计等待 %s。', formatMissionTime(max(tBurn-simTime,0))));
        end
    end

    function armStep2(kind, tBurn, seg, targetGuide, phaseName, orbitName, nextAdvice, detailText)
        if nargin < 4 || isempty(targetGuide)
            targetGuide = [];
        end
        mission.previewSeg = seg;
        mission.targetSeg = targetGuide;
        mission.pending = struct('active',true,'time',tBurn,'kind',kind,'segment',seg);
        mission.stepState(2) = 3;
        mission.running = true;
        setStatus(phaseName, orbitName, nextAdvice, detailText);
    end

    function pressStep3()
        switch mission.styleTag
            case 'apollo_out'
                mission.activeSeg = buildApolloLOICapture(simTime);
                mission.previewSeg = [];
                mission.targetSeg = buildApolloLowLunarTarget(simTime);
                mission.onActiveEnd = 'apollo_out_unlock4';
                mission.stepState(3) = 3;
                mission.running = true;
                setStatus('LOI 捕获阶段', '月心捕获椭圆', ...
                    'LOI 已经开始。飞船正在从飞掠月球转变为被月球捕获。', ...
                    '现在蓝色低月轨才出现，因为只有在已经执行 LOI 后，展示最终低月轨才是合理的。');
            case 'artemis_out'
                mission.activeSeg = buildArtemisOPF(simTime);
                mission.previewSeg = [];
                mission.targetSeg = buildDROTarget(simTime);
                mission.onActiveEnd = 'artemis_out_unlock4';
                mission.stepState(3) = 3;
                mission.running = true;
                setStatus('外向飞越阶段', '近月飞越后过渡段', ...
                    '外向飞越已经开始。飞船正在借月球改向并前往 DRO 插入点。', ...
                    '这一步不是最终轨道，而是把自己摆到能进入 DRO 的位置。');
            case 'capstone_out'
                mission.activeSeg = buildCapstoneCapture(simTime);
                mission.previewSeg = [];
                mission.targetSeg = buildNRHOTarget(simTime);
                mission.onActiveEnd = 'capstone_out_unlock4';
                mission.stepState(3) = 3;
                mission.running = true;
                setStatus('低能捕获阶段', '月心捕获椭圆', ...
                    '低能捕获已经开始。飞船正在从 BLT 通道切入月球相关轨道。', ...
                    '这一步的核心不是猛刹车，而是顺着已经磨好的能量状态平滑进入驻留轨道。');
            case 'apollo_in'
                mission.activeSeg = buildDirectEntry(simTime);
                mission.previewSeg = [];
                mission.targetSeg = [];
                mission.onActiveEnd = 'apollo_in_unlock4';
                mission.stepState(3) = 3;
                mission.running = true;
                setStatus('地球再入阶段', '再入弧段', ...
                    '地球再入已经开始。飞船正在从返地椭圆转入大气再入弧段。', ...
                    '这一步跑完后，最后的"返回完成"按钮才会亮起。');
            case 'artemis_in'
                mission.activeSeg = buildArtemisRPF(simTime);
                mission.previewSeg = [];
                mission.targetSeg = [];
                mission.onActiveEnd = 'artemis_in_unlock4';
                mission.stepState(3) = 3;
                mission.running = true;
                setStatus('返程飞越阶段', '返地过渡弧段', ...
                    '返程飞越已经开始。飞船正在被摆正到返地走廊。', ...
                    '只有返程飞越跑完，最后的"地球再入"按钮才会亮起。');
            case 'change5_in'
                mission.activeSeg = buildSkipEntry(simTime);
                mission.previewSeg = [];
                mission.targetSeg = [];
                mission.onActiveEnd = 'change5_in_unlock4';
                mission.stepState(3) = 3;
                mission.running = true;
                setStatus('跳跃再入阶段', '两段式再入弧段', ...
                    '跳跃再入已经开始。飞船会先擦入大气减能，再进入最终回收弧段。', ...
                    '这一步结束后，最后的"返回完成"按钮才会亮起。');
        end
    end

    function pressStep4()
        switch mission.styleTag
            case 'apollo_out'
                localAngle = getMoonRelativeAngleAtCurrent(mission.activeSeg, simTime);
                mission.activeSeg = makeMoonCircular(rLunarPark, localAngle, simTime, +1, '低月轨');
                mission.previewSeg = [];
                mission.targetSeg = [];
                mission.onActiveEnd = 'none';
                mission.stepState(4) = 2;
                mission.running = true;
                mission.completed = true;
                setStatus('低月轨阶段', '低月停泊圆轨道', ...
                    'Apollo 直接转移去程演示完成。飞船已经稳定进入低月轨。', ...
                    '完整链路是：地球停泊轨道 → TLI → LOI → 低月轨。');
            case 'artemis_out'
                localAngle = getMoonRelativeAngleAtCurrent(mission.activeSeg, simTime);
                mission.activeSeg = makeMoonCircular(rDRO, localAngle, simTime, -1, 'DRO');
                mission.previewSeg = [];
                mission.targetSeg = [];
                mission.onActiveEnd = 'none';
                mission.stepState(4) = 2;
                mission.running = true;
                mission.completed = true;
                setStatus('DRO 驻留阶段', '远逆行轨道', ...
                    'Artemis 风格去程演示完成。飞船已经进入 DRO。', ...
                    '完整链路是：地球停泊轨道 → TLI → 外向飞越 → 进入 DRO。');
            case 'capstone_out'
                mission.activeSeg = buildNRHOPeriodicAtCurrent();
                mission.previewSeg = [];
                mission.targetSeg = [];
                mission.onActiveEnd = 'none';
                mission.stepState(4) = 2;
                mission.running = true;
                mission.completed = true;
                setStatus('NRHO 驻留阶段', '近月高偏心驻留轨道', ...
                    'CAPSTONE 风格去程演示完成。飞船已经进入 NRHO。', ...
                    '完整链路是：地球远地点抬升 → BLT 出发 → 低能捕获 → NRHO。');
            case 'apollo_in'
                mission.entryEndPoint = evalSegment(mission.activeSeg, simTime);
                mission.activeSeg = makeFixedPoint(mission.entryEndPoint, '返回完成');
                mission.previewSeg = [];
                mission.targetSeg = [];
                mission.onActiveEnd = 'none';
                mission.stepState(4) = 2;
                mission.running = false;
                mission.completed = true;
                set(hSplash,'XData',mission.entryEndPoint(1),'YData',mission.entryEndPoint(2), ...
                    'ZData',mission.entryEndPoint(3),'Visible','on');
                setStatus('返回完成', '已结束轨道飞行', ...
                    'Apollo 返程演示完成，返回点已经固定。', ...
                    '完整链路是：低月轨 → TEI → 地球再入 → 返回完成。');
            case 'artemis_in'
                mission.activeSeg = buildArtemisEarthEntry(simTime);
                mission.previewSeg = [];
                mission.targetSeg = [];
                mission.onActiveEnd = 'artemis_in_finish';
                mission.stepState(4) = 3;
                mission.running = true;
                setStatus('地球再入阶段', 'Skip Entry 再入弧段', ...
                    '地球再入已经开始。飞船正在执行 Artemis 风格的最终再入。', ...
                    '这是最后一个主动步骤；再入弧段结束后，系统会自动固定回收点。');
            case 'change5_in'
                mission.entryEndPoint = evalSegment(mission.activeSeg, simTime);
                mission.activeSeg = makeFixedPoint(mission.entryEndPoint, '返回完成');
                mission.previewSeg = [];
                mission.targetSeg = [];
                mission.onActiveEnd = 'none';
                mission.stepState(4) = 2;
                mission.running = false;
                mission.completed = true;
                set(hSplash,'XData',mission.entryEndPoint(1),'YData',mission.entryEndPoint(2), ...
                    'ZData',mission.entryEndPoint(3),'Visible','on');
                setStatus('返回完成', '已结束轨道飞行', ...
                    '嫦娥五号风格返程演示完成，回收点已经固定。', ...
                    '完整链路是：月球返回准备 → TEI → 跳跃再入 → 返回完成。');
        end
    end

%% ===================== 统一任务时钟 =====================
    function advanceMissionClock(dt)
        if dt <= 0
            return;
        end

        nextEventTime = inf;
        nextEventKind = 'none';

        if mission.pending.active
            nextEventTime = mission.pending.time;
            nextEventKind = 'pending';
        end

        if isFiniteSegment(mission.activeSeg)
            if mission.activeSeg.tEnd > simTime && mission.activeSeg.tEnd < nextEventTime
                nextEventTime = mission.activeSeg.tEnd;
                nextEventKind = 'segmentEnd';
            end
        end

        if isfinite(nextEventTime) && nextEventTime <= simTime + dt
            simTime = nextEventTime;
            addTrailPoint();
            switch nextEventKind
                case 'pending'
                    executePending();
                case 'segmentEnd'
                    handleActiveSegmentEnd();
            end
        else
            simTime = simTime + dt;
            addTrailPoint();
        end
    end

    function executePending()
        kind = mission.pending.kind;
        seg  = mission.pending.segment;
        mission.pending = struct('active',false,'time',NaN,'kind','none','segment',[]);
        mission.previewSeg = [];

        switch kind
            case 'apollo_out_burn'
                mission.activeSeg = seg;
                mission.onActiveEnd = 'apollo_out_unlock3';
                setStatus('地月转移阶段', '地心转移椭圆', ...
                    'TLI 已经执行。飞船正在沿转移椭圆飞向月球；蓝色月球窗口表示真正要去的近月遭遇位置。到达那里之前，LOI 不会亮起。', ...
                    '现在看到的是完整的"怎么去"：先把轨道拉长碰到月球窗口，再在遭遇点做捕获，而不是一路直接贴着月球飞。');
            case 'artemis_out_burn'
                mission.activeSeg = seg;
                mission.onActiveEnd = 'artemis_out_unlock3';
                setStatus('第一段地月转移阶段', '飞向近月飞越点的转移椭圆', ...
                    '第一段转移已经开始。飞船正在飞向蓝色近月飞越窗口；真正的目标仍然是后续外向飞越，而不是现在就进 DRO。', ...
                    '现在看到的是第一段如何把自己送到飞越门口：先对准近月飞越窗口，再借月球改向，最后才进入 DRO。');
            case 'capstone_out_burn'
                mission.activeSeg = seg;
                mission.onActiveEnd = 'capstone_out_unlock3';
                setStatus('BLT 低能转移阶段', '低能通道', ...
                    'BLT 出发已经执行。飞船正在沿低能通道缓慢接近月球。', ...
                    '这一步强调省推进剂，所以轨迹更长、时间更久。');
            case 'apollo_in_burn'
                mission.activeSeg = seg;
                mission.onActiveEnd = 'apollo_in_unlock3';
                setStatus('月地转移阶段', '返地椭圆', ...
                    'TEI 已经执行。飞船正在从月球返回地球。到达地球再入接口前，下一步不会亮起。', ...
                    '这一步的本质是把飞船从"绕月"切换成"回地球"。');
            case 'artemis_in_burn'
                mission.activeSeg = seg;
                mission.onActiveEnd = 'artemis_in_unlock3';
                setStatus('离开 DRO 阶段', '离开 DRO 的过渡段', ...
                    '离开 DRO 已经开始。飞船正在向近月返程飞越点下降。', ...
                    '这一步仍然不是直接回地球，而是先从 DRO 动力学系统中脱离。');
            case 'change5_in_burn'
                mission.activeSeg = seg;
                mission.onActiveEnd = 'change5_in_unlock3';
                setStatus('高速返地阶段', '返地弧段', ...
                    'TEI 已经执行。飞船正在高速返回地球。到达再入窗口之前，跳跃再入不会亮起。', ...
                    '这一步真正要控制的不是能不能回到地球，而是后续如何安全再入。');
        end
    end

    function handleActiveSegmentEnd()
        switch mission.onActiveEnd
            case 'apollo_out_unlock3'
                mission.running = false; mission.stepState(2) = 2; mission.stepState(3) = 1; mission.onActiveEnd = 'none';
                setStatus('到达近月遭遇点', '地月转移椭圆末端', ...
                    'LOI 现在已经亮起。飞船已经精确到达近月遭遇窗口；按下后，展示会从"够到月球"切换成"被月球抓住"。', ...
                    '这里冻结的是精确遭遇时刻：飞船、月球和窗口一起静止，便于你清楚看到下一步为什么是 LOI。');
            case 'artemis_out_unlock3'
                mission.running = false; mission.stepState(2) = 2; mission.stepState(3) = 1; mission.onActiveEnd = 'none';
                setStatus('到达近月飞越点', '第一段转移末端', ...
                    '外向飞越按钮现在已经亮起。飞船已经精确到达近月飞越窗口；按下后，会先借月球改向，再去接近 DRO 插入位置。', ...
                    '这里冻结的是飞越开始前的精确时刻，所以你能先看清"先飞越、后入轨"的逻辑，再继续。');
            case 'capstone_out_unlock3'
                mission.running = false; mission.stepState(2) = 2; mission.stepState(3) = 1; mission.onActiveEnd = 'none';
                setStatus('到达月球捕获窗口', '低能转移末端', ...
                    '低能捕获按钮现在已经亮起。按下后，飞船会从 BLT 通道切入月球捕获段。', ...
                    '现在系统冻结在真正的捕获窗口，便于你清楚看到下一步该做什么。');
            case 'apollo_out_unlock4'
                mission.running = false; mission.stepState(3) = 2; mission.stepState(4) = 1; mission.onActiveEnd = 'none';
                setStatus('LOI 捕获段完成', '月心捕获椭圆末端', ...
                    '低月轨按钮现在已经亮起。按下后，飞船会圆化进入最终低月轨。', ...
                    '捕获已经完成，最后一步只差把轨道收紧成稳定低月轨。');
            case 'artemis_out_unlock4'
                mission.running = false; mission.stepState(3) = 2; mission.stepState(4) = 1; mission.onActiveEnd = 'none';
                setStatus('外向飞越段完成', 'DRO 插入点附近', ...
                    '进入 DRO 按钮现在已经亮起。按下后，飞船会稳定进入 DRO。', ...
                    '飞越已经完成，最后只差正式锁进目标驻留轨道。');
            case 'capstone_out_unlock4'
                mission.running = false; mission.stepState(3) = 2; mission.stepState(4) = 1; mission.onActiveEnd = 'none';
                setStatus('低能捕获段完成', 'NRHO 插入点附近', ...
                    'NRHO 按钮现在已经亮起。按下后，飞船会稳定进入目标驻留轨道。', ...
                    '捕获阶段已经做完，最后只差建立长期驻留轨道。');
            case 'apollo_in_unlock3'
                mission.running = false; mission.stepState(2) = 2; mission.stepState(3) = 1; mission.onActiveEnd = 'none';
                setStatus('到达地球再入接口', '返地椭圆末端', ...
                    '地球再入按钮现在已经亮起。按下后，飞船会进入地球再入弧段。', ...
                    '返地椭圆已经飞完，但真正的再入过程还没有开始。');
            case 'artemis_in_unlock3'
                mission.running = false; mission.stepState(2) = 2; mission.stepState(3) = 1; mission.onActiveEnd = 'none';
                setStatus('到达近月返程飞越点', '离开 DRO 的过渡段末端', ...
                    '返程飞越按钮现在已经亮起。按下后，飞船会被摆正到返地走廊。', ...
                    '这一步强调的是：先离开 DRO，再利用飞越完成返地方向控制。');
            case 'change5_in_unlock3'
                mission.running = false; mission.stepState(2) = 2; mission.stepState(3) = 1; mission.onActiveEnd = 'none';
                setStatus('到达高速再入窗口', '返地弧段末端', ...
                    '跳跃再入按钮现在已经亮起。按下后，飞船会进入两段式减能过程。', ...
                    '现在已经飞到了地球边上，接下来真正考验的是再入方式。');
            case 'apollo_in_unlock4'
                mission.running = false; mission.stepState(3) = 2; mission.stepState(4) = 1; mission.onActiveEnd = 'none';
                setStatus('再入弧段完成', '回收点上空', ...
                    '返回完成按钮现在已经亮起。按下后，系统会固定回收点并标出返回位置。', ...
                    '再入飞行已经跑完，最后只差确认任务完成。');
            case 'artemis_in_unlock4'
                mission.running = false; mission.stepState(3) = 2; mission.stepState(4) = 1; mission.onActiveEnd = 'none';
                setStatus('返程飞越完成', '地球再入接口', ...
                    '地球再入按钮现在已经亮起。按下后，系统会开始最后的 Skip Entry 弧段。', ...
                    '从 DRO 到返地走廊这件事已经完成，接下来只剩最后的回地球。');
            case 'change5_in_unlock4'
                mission.running = false; mission.stepState(3) = 2; mission.stepState(4) = 1; mission.onActiveEnd = 'none';
                setStatus('跳跃再入完成', '最终回收点附近', ...
                    '返回完成按钮现在已经亮起。按下后，系统会固定最终回收点。', ...
                    '高速减能过程已经跑完，最后只差确认回收完成。');
            case 'artemis_in_finish'
                mission.entryEndPoint = evalSegment(mission.activeSeg, simTime);
                mission.activeSeg = makeFixedPoint(mission.entryEndPoint, '返回完成');
                mission.previewSeg = [];
                mission.targetSeg = [];
                mission.onActiveEnd = 'none';
                mission.running = false;
                mission.stepState(4) = 2;
                mission.completed = true;
                set(hSplash,'XData',mission.entryEndPoint(1),'YData',mission.entryEndPoint(2), ...
                    'ZData',mission.entryEndPoint(3),'Visible','on');
                setStatus('返回完成', '已结束轨道飞行', ...
                    'Artemis 风格返程演示完成，回收点已经固定。', ...
                    '完整链路是：DRO → 离开 DRO → 返程飞越 → 地球再入。');
        end
    end

%% ===================== 场景刷新 =====================
    function updateScene()
        moonOrbitXYZ = sampleMoonOrbit(720);
        set(hMoonOrbit,'XData',moonOrbitXYZ(1,:),'YData',moonOrbitXYZ(2,:),'ZData',moonOrbitXYZ(3,:));

        [moonPos, moonTheta] = getMoonState(simTime);
        set(earthTranslate,'Matrix',makehgtform('translate',[0 0 0]));
        set(earthRotate,'Matrix',makehgtform('zrotate',omegaEarth*simTime));
        set(moonTranslate,'Matrix',makehgtform('translate',moonPos.'));
        set(moonRotate,'Matrix',makehgtform('zrotate',moonTheta + 0.35));

        craftPos = evalSegment(mission.activeSeg, simTime);
        set(hCraft,'XData',craftPos(1),'YData',craftPos(2),'ZData',craftPos(3));

        currentXYZ = nan(3,0);
        transferXYZ = nan(3,0);
        targetXYZ = nan(3,0);

        if isOrbitLike(mission.activeSeg)
            currentXYZ = sampleDisplaySegment(mission.activeSeg, orbitSamples);
        elseif strcmp(mission.activeSeg.type,'fixed')
            currentXYZ = craftPos;
        end

        if mission.pending.active && ~isempty(mission.previewSeg)
            transferXYZ = sampleDisplaySegment(mission.previewSeg, transferSamples);
        elseif ~isOrbitLike(mission.activeSeg) && ~strcmp(mission.activeSeg.type,'fixed')
            transferXYZ = sampleDisplaySegment(mission.activeSeg, transferSamples);
        end

        if ~isempty(mission.targetSeg)
            targetXYZ = sampleDisplaySegment(mission.targetSeg, orbitSamples);
        end

        set(hCurrent,'XData',currentXYZ(1,:),'YData',currentXYZ(2,:),'ZData',currentXYZ(3,:));
        set(hTransfer,'XData',transferXYZ(1,:),'YData',transferXYZ(2,:),'ZData',transferXYZ(3,:));
        set(hTarget,'XData',targetXYZ(1,:),'YData',targetXYZ(2,:),'ZData',targetXYZ(3,:));

        set(hTrail,'XData',trailXYZ(1,:),'YData',trailXYZ(2,:),'ZData',trailXYZ(3,:));
        applyCamera(craftPos, moonPos, moonTheta);
        updateButtons();
        updateInfoText();
    end

    function applyCamera(craftPos, moonPos, moonTheta)
        center = craftPos;
        if isfield(mission.activeSeg,'trackBody')
            switch mission.activeSeg.trackBody
                case 'earth'
                    center = [0;0;0];
                case 'moon'
                    center = moonPos;
                otherwise
                    center = craftPos;
            end
        end

        span = axisHalfSpan;
        axis(ax, [center(1)-span center(1)+span center(2)-span center(2)+span center(3)-span center(3)+span]);

        switch viewMode
            case 1
                view(ax, 38, 24);
            case 2
                view(ax, 0, 90);
            case 3
                az = rad2deg(moonTheta) + 10;
                view(ax, az, 14);
            case 4
                vel = approxVelocity(mission.activeSeg, simTime);
                if norm(vel(1:2)) < 1e-6
                    view(ax, 38, 24);
                else
                    az = rad2deg(atan2(vel(2), vel(1))) - 18;
                    view(ax, az, 18);
                end
        end
    end

    function addTrailPoint()
        craftPos = evalSegment(mission.activeSeg, simTime);
        if any(isnan(lastTrailPoint))
            trailXYZ = craftPos;
            lastTrailPoint = craftPos;
        else
            if norm(craftPos - lastTrailPoint) >= trailMinStep
                trailXYZ(:,end+1) = craftPos; %#ok<AGROW>
                lastTrailPoint = craftPos;
            end
        end
        if size(trailXYZ,2) > trailMax
            trailXYZ = trailXYZ(:, end-trailMax+1:end);
        end
    end

    function applyDefaultView()
        view(ax, 38, 24);
    end

%% ===================== 文本与按钮 =====================
    function setStatus(phaseName, orbitName, nextAdvice, detailText)
        mission.phaseName = phaseName;
        mission.orbitName = orbitName;
        mission.nextAdvice = nextAdvice;
        mission.detail = detailText;
    end

    function updateInfoText()
        if mission.pending.active
            extra = sprintf('\n\n下一事件倒计时：%s', formatMissionTime(max(mission.pending.time - simTime, 0)));
        elseif mission.running && isFiniteSegment(mission.activeSeg)
            extra = sprintf('\n\n当前阶段剩余时间：%s', formatMissionTime(max(mission.activeSeg.tEnd - simTime, 0)));
        else
            extra = '\n\n当前状态：时间冻结，等待你的下一步操作。';
        end

        str = sprintf(['当前是什么阶段：%s\n\n', ...
            '运行在哪个轨道：%s\n\n', ...
            '接下来怎么做：%s\n\n', ...
            '过程说明：%s\n\n', ...
            '当前风格：%s'], ...
            mission.phaseName, mission.orbitName, mission.nextAdvice, mission.detail, mission.summary);
        set(infoText,'String',[str extra]);
    end

    function updateButtons()
        colors.disabled = [0.84 0.84 0.84];
        colors.enabled  = [0.80 1.00 0.80];
        colors.done     = [0.75 0.88 1.00];
        colors.waiting  = [1.00 0.93 0.66];

        for ii = 1:4
            set(stepBtn(ii),'String',mission.stepLabels{ii});
            switch mission.stepState(ii)
                case 0
                    set(stepBtn(ii),'Enable','off','BackgroundColor',colors.disabled,'ForegroundColor',[0.35 0.35 0.35]);
                case 1
                    set(stepBtn(ii),'Enable','on','BackgroundColor',colors.enabled,'ForegroundColor','k');
                case 2
                    set(stepBtn(ii),'Enable','off','BackgroundColor',colors.done,'ForegroundColor','k');
                case 3
                    set(stepBtn(ii),'Enable','off','BackgroundColor',colors.waiting,'ForegroundColor','k');
            end
        end
    end

%% ===================== 构造函数 =====================
    function seg = buildApolloOutboundTransfer(tBurn)
        thetaBurn = getEarthAngle(mission.activeSeg, tBurn);
        seg = makeEarthEllipse(rEarthPark, aMoon - rApolloPeri, thetaBurn, tBurn, true, 'TLI 地月转移段');
    end

    function seg = buildApolloLOICapture(tNow)
        craftPos = evalSegment(mission.activeSeg, tNow);
        [moonPos, moonThetaNow] = getMoonState(tNow);
        relLocal = rotz2(-moonThetaNow) * (craftPos - moonPos);
        localStart = atan2(relLocal(2), relLocal(1));
        r0 = norm(relLocal(1:2));
        localEnd = wrapToPi(localStart - 0.78*pi);
        P0 = relLocal;
        P3 = rotz2(localEnd) * [rLunarPark; 0; 0];
        P1 = rotz2(localStart - 0.22*pi) * [max(0.82*r0, 1.35*rLunarPark); 0; 0] + [0;0;4300];
        P2 = rotz2(localEnd + 0.20*pi) * [1.18*rLunarPark; 0; 0] + [0;0;1600];
        seg = makeMoonMovingBezier(P0, P1, P2, P3, tNow, 4.5*3600, 'LOI 捕获段');
    end

    function seg = buildApolloLowLunarTarget(tNow)
        localAngle = getMoonRelativeAngleAtCurrent(mission.activeSeg, tNow);
        seg = makeMoonCircular(rLunarPark, localAngle, tNow, +1, '低月轨');
    end

    function seg = buildArtemisOutboundTransfer(tBurn)
        thetaBurn = getEarthAngle(mission.activeSeg, tBurn);
        seg = makeEarthEllipse(rEarthPark, aMoon - rFlybyPeri, thetaBurn, tBurn, true, '飞向近月飞越点');
    end

    function seg = buildArtemisOPF(tNow)
        [moonPos, moonThetaNow] = getMoonState(tNow);
        startPt = evalSegment(mission.activeSeg, tNow);
        relLocal = rotz2(-moonThetaNow) * (startPt - moonPos);
        localStart = atan2(relLocal(2), relLocal(1));
        P0 = relLocal;
        P3 = rotz2(0.62*pi) * [rDRO; 0; 0];
        P1 = rotz2(localStart + 0.28*pi) * [max(1.7*rFlybyPeri, 1.25*norm(relLocal(1:2))); 0; 0] + [0;0;15000];
        P2 = rotz2(0.74*pi) * [1.08*rDRO; 0; 0] + [0;0;12000];
        seg = makeMoonMovingBezier(P0, P1, P2, P3, tNow, 18*3600, '外向飞越 OPF');
    end

    function seg = buildDROTarget(tNow)
        localAngle = getMoonRelativeAngleAtCurrent(mission.activeSeg, tNow);
        seg = makeMoonCircular(rDRO, localAngle, tNow, -1, 'DRO');
    end

    function seg = buildCapstoneBLT(tBurn)
        tArr = tBurn + 18*86400;
        startPt = evalSegment(mission.activeSeg, tBurn);
        [moonPosArr, moonThetaArr] = getMoonState(tArr);
        endPt = moonPosArr + rotz2(moonThetaArr + pi) * [rNRHORp; 0; 0];
        c1 = startPt + [250000; 220000; 60000];
        c2 = [100000; -520000; -90000] + 0.45*moonPosArr;
        seg = makeBezier(startPt, c1, c2, endPt, tBurn, 18*86400, 'craft', 'BLT 低能转移段');
    end

    function seg = buildCapstoneCapture(tNow)
        craftPos = evalSegment(mission.activeSeg, tNow);
        [moonPos, ~] = getMoonState(tNow);
        rel = craftPos - moonPos;
        argPeri = atan2(rel(2), rel(1));
        seg = makeMoonEllipse(rNRHORp, rNRHORa, argPeri, tNow, true, '低能捕获段');
    end

    function seg = buildNRHOTarget(tNow)
        craftPos = evalSegment(mission.activeSeg, tNow);
        [moonPos, ~] = getMoonState(tNow);
        rel = craftPos - moonPos;
        argApo = atan2(rel(2), rel(1));
        argPeri = wrapToPi(argApo - pi);
        seg = makeMoonEllipsePeriodicGeneral(rNRHORp, rNRHORa, argPeri, tNow, pi, -1, 'NRHO');
    end

    function seg = buildNRHOPeriodicAtCurrent()
        craftPos = evalSegment(mission.activeSeg, simTime);
        [moonPos, ~] = getMoonState(simTime);
        rel = craftPos - moonPos;
        argApo = atan2(rel(2), rel(1));
        argPeri = wrapToPi(argApo - pi);
        seg = makeMoonEllipsePeriodicGeneral(rNRHORp, rNRHORa, argPeri, simTime, pi, -1, 'NRHO');
    end

    function seg = buildApolloInboundReturn(tBurn)
        startPt = evalSegment(mission.activeSeg, tBurn);
        apoAng = atan2(startPt(2), startPt(1));
        argPeri = wrapToPi(apoAng - pi);
        seg = makeEarthEllipse(rEntry, aMoon + rLunarPark, argPeri, tBurn, false, '返地椭圆');
    end

    function seg = buildArtemisDepartDRO(tBurn)
        [moonPos, moonThetaNow] = getMoonState(tBurn);
        startPt = evalSegment(mission.activeSeg, tBurn);
        relLocal = rotz2(-moonThetaNow) * (startPt - moonPos);
        localStart = atan2(relLocal(2), relLocal(1));
        P0 = relLocal;
        P3 = rotz2(pi) * [rFlybyPeri; 0; 0];
        P1 = rotz2(localStart - 0.32*pi) * [0.96*rDRO; 0; 0] + [0;0;13000];
        P2 = rotz2(0.78*pi) * [1.9*rFlybyPeri; 0; 0] + [0;0;8500];
        seg = makeMoonMovingBezier(P0, P1, P2, P3, tBurn, 20*3600, '离开 DRO 段');
    end

    function seg = buildArtemisRPF(tNow)
        startPt = evalSegment(mission.activeSeg, tNow);
        apoAng = atan2(startPt(2), startPt(1));
        argPeri = wrapToPi(apoAng - pi);
        seg = makeEarthEllipse(rEntry, aMoon - rFlybyPeri, argPeri, tNow, false, '返程飞越之后的返地段');
    end

    function seg = buildChange5Return(tBurn)
        startPt = evalSegment(mission.activeSeg, tBurn);
        apoAng = atan2(startPt(2), startPt(1));
        argPeri = wrapToPi(apoAng - pi);
        seg = makeEarthEllipse(rEntry, aMoon + rLunarPark, argPeri, tBurn, false, '高速返地段');
    end

    function seg = buildDirectEntry(tNow)
        startPt = evalSegment(mission.activeSeg, tNow);
        theta0 = atan2(startPt(2), startPt(1));
        endPt = rotz2(theta0 - 0.35) * [rSplash; 0; 0];
        c1 = 0.88*startPt + [0; 0; 15000];
        c2 = rotz2(theta0 - 0.15) * [Re + 800; 0; 0] + [0;0;6000];
        seg = makeBezier(startPt, c1, c2, endPt, tNow, 1600, 'craft', '地球再入段');
    end

    function seg = buildArtemisEarthEntry(tNow)
        startPt = evalSegment(mission.activeSeg, tNow);
        theta0 = atan2(startPt(2), startPt(1));
        mid1 = rotz2(theta0 - 0.10) * [Re + 400; 0; 0] + [0;0;5000];
        mid2 = rotz2(theta0 - 0.45) * [Re + 2500; 0; 0] + [0;0;16000];
        endPt = rotz2(theta0 - 0.78) * [rSplash; 0; 0];
        seg = makePiecewiseBezier(startPt, mid1, mid2, endPt, tNow, 2200, 'craft', 'Artemis Skip Entry');
    end

    function seg = buildSkipEntry(tNow)
        startPt = evalSegment(mission.activeSeg, tNow);
        theta0 = atan2(startPt(2), startPt(1));
        mid1 = rotz2(theta0 - 0.12) * [Re + 320; 0; 0] + [0;0;4000];
        mid2 = rotz2(theta0 - 0.32) * [Re + 2800; 0; 0] + [0;0;18000];
        endPt = rotz2(theta0 - 0.68) * [rSplash; 0; 0];
        seg = makePiecewiseBezier(startPt, mid1, mid2, endPt, tNow, 2400, 'craft', '跳跃再入段');
    end

%% ===================== 轨段类型 =====================
    function seg = makeIdlePoint(pos)
        seg.type = 'fixed';
        seg.pos = pos(:);
        seg.trackBody = 'earth';
        seg.label = '待命';
        seg.t0 = 0;
        seg.tEnd = inf;
    end

    function seg = makeFixedPoint(pos, label)
        seg.type = 'fixed';
        seg.pos = pos(:);
        seg.trackBody = 'craft';
        seg.label = label;
        seg.t0 = simTime;
        seg.tEnd = inf;
    end

    function seg = makeEarthCircular(rOrbit, theta0, t0, sense, label)
        seg.type = 'earthCircular';
        seg.r = rOrbit; seg.theta0 = theta0; seg.t0 = t0; seg.sense = sense;
        seg.n = sqrt(muE/rOrbit^3);
        seg.trackBody = 'earth';
        seg.label = label; seg.tEnd = inf;
    end

    function seg = makeMoonCircular(rOrbit, theta0, t0, sense, label)
        seg.type = 'moonCircular';
        seg.r = rOrbit; seg.theta0 = theta0; seg.t0 = t0; seg.sense = sense;
        seg.n = sqrt(muM/rOrbit^3);
        seg.trackBody = 'moon';
        seg.label = label; seg.tEnd = inf;
    end

    function seg = makeEarthEllipse(rp, ra, argPeri, t0, startAtPeri, label)
        seg.type = 'earthEllipse';
        seg.rp = rp; seg.ra = ra; seg.a = (rp+ra)/2; seg.e = (ra-rp)/(ra+rp); seg.arg = argPeri;
        seg.t0 = t0; seg.n = sqrt(muE/seg.a^3); seg.M0 = 0;
        if ~startAtPeri, seg.M0 = pi; end
        seg.trackBody = 'craft'; seg.label = label; seg.tEnd = t0 + pi/seg.n;
    end

    function seg = makeMoonEllipse(rp, ra, argPeri, t0, startAtPeri, label)
        seg.type = 'moonEllipse';
        seg.rp = rp; seg.ra = ra; seg.a = (rp+ra)/2; seg.e = (ra-rp)/(ra+rp); seg.arg = argPeri;
        seg.t0 = t0; seg.n = sqrt(muM/seg.a^3); seg.M0 = 0;
        if ~startAtPeri, seg.M0 = pi; end
        seg.trackBody = 'craft'; seg.label = label; seg.tEnd = t0 + pi/seg.n;
    end

    function seg = makeEarthEllipsePeriodicGeneral(rp, ra, argPeri, t0, M0, sense, label)
        seg.type = 'earthEllipsePeriodic';
        seg.rp = rp; seg.ra = ra; seg.a = (rp+ra)/2; seg.e = (ra-rp)/(ra+rp); seg.arg = argPeri;
        seg.t0 = t0; seg.n = sqrt(muE/seg.a^3); seg.M0 = M0; seg.sense = sense;
        seg.trackBody = 'earth'; seg.label = label; seg.tEnd = inf;
    end

    function seg = makeMoonEllipsePeriodicGeneral(rp, ra, argPeri, t0, M0, sense, label)
        seg.type = 'moonEllipsePeriodic';
        seg.rp = rp; seg.ra = ra; seg.a = (rp+ra)/2; seg.e = (ra-rp)/(ra+rp); seg.arg = argPeri;
        seg.t0 = t0; seg.n = sqrt(muM/seg.a^3); seg.M0 = M0; seg.sense = sense;
        seg.trackBody = 'moon'; seg.label = label; seg.tEnd = inf;
    end

    function seg = makeBezier(P0,P1,P2,P3,t0,duration,trackBody,label)
        seg.type = 'bezier';
        seg.P = [P0(:), P1(:), P2(:), P3(:)];
        seg.t0 = t0; seg.duration = duration; seg.tEnd = t0 + duration;
        seg.trackBody = trackBody; seg.label = label;
    end

    function seg = makeMoonMovingBezier(P0,P1,P2,P3,t0,duration,label)
        seg.type = 'moonMovingBezier';
        seg.P = [P0(:), P1(:), P2(:), P3(:)];
        seg.thetaRef = getMoonAngle(t0);
        seg.t0 = t0; seg.duration = duration; seg.tEnd = t0 + duration;
        seg.trackBody = 'craft'; seg.label = label;
    end

    function seg = makeMoonArc(rOrbit, thetaCenter, halfWidth, t0, label)
        seg.type = 'moonArc';
        seg.r = rOrbit; seg.thetaCenter = thetaCenter; seg.halfWidth = halfWidth;
        seg.t0 = t0; seg.tEnd = inf; seg.trackBody = 'moon'; seg.label = label;
    end

    function seg = makePiecewiseBezier(P0,Mid1,Mid2,P3,t0,duration,trackBody,label)
        P01 = P0(:); P03 = Mid1(:);
        P11 = 0.78*P01 + 0.22*P03 + [0;0;-3000];
        P12 = 0.35*P01 + 0.65*P03 + [0;0;-1000];
        Q0 = P03(:); Q3 = P3(:); Q1 = Mid2(:); Q2 = 0.38*Mid2(:) + 0.62*Q3 + [0;0;2800];
        seg.type = 'piecewiseBezier';
        seg.Pa = [P01, P11, P12, P03];
        seg.Pb = [Q0, Q1, Q2, Q3];
        seg.t0 = t0; seg.duration = duration; seg.tSplit = t0 + 0.43*duration; seg.tEnd = t0 + duration;
        seg.trackBody = trackBody; seg.label = label;
    end

%% ===================== 轨迹求值 =====================
    function pos = evalSegment(seg, t)
        switch seg.type
            case 'fixed'
                pos = seg.pos;
            case 'earthCircular'
                th = seg.theta0 + seg.sense*seg.n*(t - seg.t0);
                pos = [seg.r*cos(th); seg.r*sin(th); 0];
            case 'moonCircular'
                [moonPos, moonTheta] = getMoonState(t);
                thLocal = seg.theta0 + seg.sense*seg.n*(t - seg.t0);
                th = moonTheta + thLocal;
                pos = moonPos + [seg.r*cos(th); seg.r*sin(th); 0];
            case 'earthEllipse'
                tt = min(max(t, seg.t0), seg.tEnd);
                M = seg.M0 + seg.n*(tt - seg.t0);
                E = solveKeplerElliptic(M, seg.e);
                nu = 2*atan2(sqrt(1+seg.e)*sin(E/2), sqrt(1-seg.e)*cos(E/2));
                rr = seg.a*(1 - seg.e*cos(E));
                pos = [rr*cos(seg.arg + nu); rr*sin(seg.arg + nu); 0];
            case 'moonEllipse'
                tt = min(max(t, seg.t0), seg.tEnd);
                M = seg.M0 + seg.n*(tt - seg.t0);
                E = solveKeplerElliptic(M, seg.e);
                nu = 2*atan2(sqrt(1+seg.e)*sin(E/2), sqrt(1-seg.e)*cos(E/2));
                rr = seg.a*(1 - seg.e*cos(E));
                [moonPos, ~] = getMoonState(tt);
                pos = moonPos + [rr*cos(seg.arg + nu); rr*sin(seg.arg + nu); 0];
            case 'earthEllipsePeriodic'
                M = seg.M0 + seg.sense*seg.n*(t - seg.t0);
                E = solveKeplerElliptic(M, seg.e);
                nu = 2*atan2(sqrt(1+seg.e)*sin(E/2), sqrt(1-seg.e)*cos(E/2));
                rr = seg.a*(1 - seg.e*cos(E));
                pos = [rr*cos(seg.arg + nu); rr*sin(seg.arg + nu); 0];
            case 'moonEllipsePeriodic'
                M = seg.M0 + seg.sense*seg.n*(t - seg.t0);
                E = solveKeplerElliptic(M, seg.e);
                nu = 2*atan2(sqrt(1+seg.e)*sin(E/2), sqrt(1-seg.e)*cos(E/2));
                rr = seg.a*(1 - seg.e*cos(E));
                [moonPos, ~] = getMoonState(t);
                pos = moonPos + [rr*cos(seg.arg + nu); rr*sin(seg.arg + nu); 0];
            case 'bezier'
                u = smoothstep(clamp01((t - seg.t0)/seg.duration));
                pos = cubicBezier(seg.P, u);
            case 'moonMovingBezier'
                u = smoothstep(clamp01((t - seg.t0)/seg.duration));
                local = cubicBezier(seg.P, u);
                [moonPos, moonTheta] = getMoonState(t);
                pos = moonPos + rotz2(moonTheta - seg.thetaRef) * local;
            case 'moonArc'
                [moonPos, moonTheta] = getMoonState(t);
                pos = moonPos + [seg.r*cos(moonTheta + seg.thetaCenter); seg.r*sin(moonTheta + seg.thetaCenter); 0];
            case 'piecewiseBezier'
                if t <= seg.tSplit
                    u = smoothstep(clamp01((t - seg.t0)/(seg.tSplit - seg.t0)));
                    pos = cubicBezier(seg.Pa, u);
                else
                    u = smoothstep(clamp01((t - seg.tSplit)/(seg.tEnd - seg.tSplit)));
                    pos = cubicBezier(seg.Pb, u);
                end
            otherwise
                pos = [0;0;0];
        end
    end

    function xyz = sampleDisplaySegment(seg, n)
        if isempty(seg)
            xyz = nan(3,0); return;
        end
        switch seg.type
            case {'earthCircular','moonCircular','earthEllipsePeriodic','moonEllipsePeriodic'}
                tt = linspace(simTime, simTime + getDisplayPeriod(seg), n);
            case {'earthEllipse','moonEllipse','bezier','moonMovingBezier','piecewiseBezier'}
                tt = linspace(seg.t0, seg.tEnd, n);
            case 'moonArc'
                [moonPos, moonTheta] = getMoonState(simTime);
                ang = linspace(seg.thetaCenter-seg.halfWidth, seg.thetaCenter+seg.halfWidth, n);
                xyz = moonPos + [seg.r*cos(moonTheta + ang); seg.r*sin(moonTheta + ang); zeros(1,n)];
                return;
            case 'fixed'
                xyz = seg.pos; return;
            otherwise
                tt = linspace(simTime, simTime+1, n);
        end
        xyz = nan(3,numel(tt));
        for k = 1:numel(tt)
            xyz(:,k) = evalSegment(seg, tt(k));
        end
    end

    function tf = isOrbitLike(seg)
        tf = ismember(seg.type, {'earthCircular','moonCircular','earthEllipsePeriodic','moonEllipsePeriodic'});
    end

    function tf = isFiniteSegment(seg)
        tf = isfield(seg,'tEnd') && isfinite(seg.tEnd) && ~isOrbitLike(seg) && ~strcmp(seg.type,'fixed');
    end

    function Tdisp = getDisplayPeriod(seg)
        switch seg.type
            case {'earthCircular','earthEllipsePeriodic'}
                Tdisp = 2*pi/seg.n;
            case {'moonCircular','moonEllipsePeriodic'}
                Tdisp = 2*pi/seg.n;
            otherwise
                Tdisp = 1;
        end
    end

    function vel = approxVelocity(seg, t)
        dt = 1;
        vel = (evalSegment(seg,t+dt) - evalSegment(seg,max(t-dt,0))) / (2*dt);
    end

    function theta = getEarthAngle(seg, t)
        pos = evalSegment(seg,t);
        theta = wrapToPi(atan2(pos(2), pos(1)));
    end

    function thetaLocal = getMoonRelativeAngleAtCurrent(seg, t)
        craftPos = evalSegment(seg,t);
        [moonPos, moonTheta] = getMoonState(t);
        rel = craftPos - moonPos;
        thetaLocal = wrapToPi(atan2(rel(2), rel(1)) - moonTheta);
    end

    function seg = buildMoonWindowAtSegmentEnd(segIn, label, halfWidth)
        if nargin < 3, halfWidth = 0.18*pi; end
        tRef = segIn.tEnd;
        p = evalSegment(segIn, tRef);
        [moonPos, moonTheta] = getMoonState(tRef);
        rel = p - moonPos;
        seg = makeMoonArc(norm(rel(1:2)), wrapToPi(atan2(rel(2), rel(1)) - moonTheta), halfWidth, tRef, label);
    end

%% ===================== 窗口求解 =====================
    function tBurn = solveApolloOutboundBurnTime(segOrbit, tNow, rpStart, rArrival)
        aT = (rpStart + rArrival)/2;
        tof = pi*sqrt(aT^3/muE);
        thetaNow = getEarthAngle(segOrbit, tNow);
        moonNow  = getMoonAngle(tNow);
        rate = segOrbit.sense*segOrbit.n - omegaMoon;
        if abs(rate) < 1e-12
            tBurn = tNow + 60;
            return;
        end
        base = (moonNow + omegaMoon*tof - thetaNow - pi) / rate;
        period = abs(2*pi / rate);
        k = ceil((1 - base)/period);
        dt = base + k*period;
        if dt < 1, dt = dt + period; end
        tBurn = tNow + dt;
    end

    function tNext = nextMoonLocalPhase(segOrbit, tNow, targetLocal)
        localNow = segOrbit.theta0 + segOrbit.sense*segOrbit.n*(tNow - segOrbit.t0);
        if segOrbit.sense > 0
            d = wrapTo2Pi(targetLocal - localNow);
        else
            d = wrapTo2Pi(localNow - targetLocal);
        end
        tNext = tNow + d/segOrbit.n;
        if tNext <= tNow + 1
            tNext = tNext + 2*pi/segOrbit.n;
        end
    end

    function tNext = nextEarthPeriodicPeriapsis(segOrbit, tNow)
        Mnow = segOrbit.M0 + segOrbit.sense*segOrbit.n*(tNow - segOrbit.t0);
        d = wrapTo2Pi(-Mnow);
        tNext = tNow + d/segOrbit.n;
        if tNext <= tNow + 1
            tNext = tNext + 2*pi/segOrbit.n;
        end
    end

%% ===================== 天体状态 =====================
    function [moonPos, moonTheta] = getMoonState(t)
        moonTheta = getMoonAngle(t);
        moonPos = [aMoon*cos(moonTheta); aMoon*sin(moonTheta); 0];
    end

    function ang = getMoonAngle(t)
        ang = moonPhase0 + omegaMoon*t;
    end

    function xyz = sampleMoonOrbit(n)
        ang = linspace(0,2*pi,n);
        xyz = [aMoon*cos(ang); aMoon*sin(ang); zeros(1,n)];
    end

end

%% ===================== 局部函数 =====================
function styles = getStyleCatalog(directionMode)
if directionMode == 1
    styles(1) = struct('tag','apollo_out','name','Apollo 直接转移','summary','地球停泊轨道 → TLI → LOI → 低月轨', ...
        'steps',{{'地球停泊轨道','TLI','LOI','低月轨'}});
    styles(2) = struct('tag','artemis_out','name','Artemis 飞越 / DRO','summary','地球停泊轨道 → TLI → 外向飞越 OPF → 进入 DRO', ...
        'steps',{{'地球停泊轨道','TLI','外向飞越 OPF','进入 DRO'}});
    styles(3) = struct('tag','capstone_out','name','CAPSTONE 低能转移','summary','地球远地点抬升 → BLT 出发 → 低能捕获 → NRHO', ...
        'steps',{{'地球远地点抬升','BLT 出发','低能捕获','NRHO'}});
else
    styles(1) = struct('tag','apollo_in','name','Apollo 直接返程','summary','低月轨 → TEI → 地球再入 → 返回完成', ...
        'steps',{{'低月轨','TEI','地球再入','返回完成'}});
    styles(2) = struct('tag','artemis_in','name','Artemis DRO 返程','summary','DRO → 离开 DRO → 返程飞越 RPF → 地球再入', ...
        'steps',{{'DRO','离开 DRO','返程飞越 RPF','地球再入'}});
    styles(3) = struct('tag','change5_in','name','嫦娥五号高速返地','summary','月球返回准备 → TEI → 跳跃再入 → 返回完成', ...
        'steps',{{'月球返回准备','TEI','跳跃再入','返回完成'}});
end
end

function createTexturedBody(ax, parentGroup, radius, xs, ys, zs, texFile, fallbackColor)
try
    img = imread(texFile);
    if ndims(img) == 3 && size(img,3) >= 3
        img = img(:,:,1:3);
    end
    img = flipud(img);
    surf(ax, radius*xs, radius*ys, radius*zs, ...
        'Parent', parentGroup, 'CData', img, 'FaceColor', 'texturemap', ...
        'EdgeColor', 'none', 'FaceLighting', 'gouraud', ...
        'AmbientStrength', 0.45, 'DiffuseStrength', 0.80, 'SpecularStrength', 0.12);
catch
    surf(ax, radius*xs, radius*ys, radius*zs, ...
        'Parent', parentGroup, 'FaceColor', fallbackColor, ...
        'EdgeColor', 'none', 'FaceLighting', 'gouraud', ...
        'AmbientStrength', 0.42, 'DiffuseStrength', 0.78, 'SpecularStrength', 0.10);
end
end

function E = solveKeplerElliptic(M, e)
M = mod(M, 2*pi);
if e < 1e-12
    E = M; return;
end
E = M;
for k = 1:24
    f = E - e*sin(E) - M;
    fp = 1 - e*cos(E);
    dE = -f/fp;
    E = E + dE;
    if abs(dE) < 1e-12
        break;
    end
end
end

function p = cubicBezier(P, u)
om = 1-u;
p = P(:,1)*(om^3) + 3*P(:,2)*(om^2*u) + 3*P(:,3)*(om*u^2) + P(:,4)*(u^3);
end

function R = rotz2(ang)
R = [cos(ang) -sin(ang) 0; sin(ang) cos(ang) 0; 0 0 1];
end

function y = clamp01(x)
y = min(max(x,0),1);
end

function y = smoothstep(x)
y = x.*x.*(3 - 2*x);
end

function s = formatMissionTime(tSec)
if ~isfinite(tSec)
    s = '∞'; return;
end
if tSec < 3600
    s = sprintf('%.0f 分钟', tSec/60);
elseif tSec < 86400
    h = floor(tSec/3600);
    m = floor(mod(tSec,3600)/60);
    s = sprintf('%d 小时 %d 分', h, m);
else
    d = floor(tSec/86400);
    h = floor(mod(tSec,86400)/3600);
    s = sprintf('%d 天 %d 小时', d, h);
end
end

function s = formatZoomMultiplier(v)
if abs(v - round(v)) < 1e-9
    s = sprintf('%d', round(v));
else
    s = regexprep(sprintf('%.2f', v), '0+$', '');
    s = regexprep(s, '\.$', '');
end
end

function a = wrapTo2Pi(a)
a = mod(a, 2*pi);
end

function a = wrapToPi(a)
a = mod(a + pi, 2*pi) - pi;
end
