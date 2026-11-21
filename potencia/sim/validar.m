% Porte a MATLAB de lazo_abierto.py y rizado.py (JSON-RPC contra PLECS en el puerto 1080)
function validar(carpeta)
modelo = 'modelo-planta';
run(fullfile(carpeta, 'parametros.m'));
ruta = fullfile(carpeta, [modelo '.plecs']);
out = fullfile(carpeta, 'resultados');
if ~exist(out, 'dir'), mkdir(out); end

try, rpc('plecs.close', {modelo}); catch, end
rpc('plecs.load', {ruta});

% Lazo abierto
corr = [0.2 0.5 1.0];
dt = 1e-6; nper = 4;
n = round(nper / fref / dt);
tt = 0.02 + (0:n-1) * dt;
fid = fopen(fullfile(out, 'lazo_abierto.txt'), 'w');
pr(fid, 'Iref [A]   |d1|      |i1| [A]   desfase de i respecto de d [grados]\n');
for iref = corr
    r = rpc('plecs.simulate', {modelo, struct('ModelVars', struct('Iref', iref), 'SolverOpts', struct('OutputTimes', {num2cell(tt)}))});
    v = vals(r.Values);
    [ia, ip] = fund(v{1}, fref, dt);
    [da, dp] = fund(v{2}, fref, dt);
    pr(fid, '%-10.1f %-9.4f %-10.4f %.2f\n', iref, da, ia, ip - dp);
    f = figure('Visible', 'off');
    yyaxis left; plot(tt*1e3, v{1}); ylabel('i [A]');
    yyaxis right; plot(tt*1e3, v{2}); ylabel('d');
    xlabel('t [ms]'); title(sprintf('Lazo abierto, Iref = %.1f A', iref)); grid on;
    exportgraphics(f, fullfile(out, sprintf('lazo_abierto_Iref_%02d.png', round(iref*10))), 'Resolution', 150);
    close(f);
end
fclose(fid);

% Rizado
zabs = abs(R + 1j*2*pi*fref*L);
dd = 2 * TM * fsw;
fid = fopen(fullfile(out, 'rizado.txt'), 'w');
pr(fid, 'Vdc = %g V, L = %g mH, fsw = %g kHz, perdida del tiempo muerto %.3f en d\n', Vdc, L*1e3, fsw/1e3, dd);
pr(fid, 'Iref [A]   m        teoria con m [A]   teoria con m - dd [A]   PLECS [A]   diferencia   instante del maximo [ms]\n');
for iref = corr
    r = rpc('plecs.simulate', {modelo, struct('ModelVars', struct('Iref', iref))});
    t = r.Time(:)'; vv = vals(r.Values); i = vv{1}(:)';
    [tm, ppm, tp, pp] = rizado(t, i, Ts);
    m = zabs * iref / Vdc;
    ideal = dI(m, Vdc, L, fsw);
    contm = dI(m - dd, Vdc, L, fsw);
    pr(fid, '%-10.1f %-8.3f %-18.4f %-23.4f %-11.4f %+.1f %%       %.2f\n', iref, m, ideal, contm, ppm, 100*(ppm/contm-1), tm*1e3);
    f = figure('Visible', 'off');
    subplot(2,1,1); plot(t*1e3, i); xlim([40 60]); ylabel('i [A]'); grid on;
    title(sprintf('Rizado, Iref = %.1f A', iref));
    subplot(2,1,2); plot(tp*1e3, pp*1e3, '.-'); ylabel('rizado pp [mA]'); xlabel('t [ms]'); grid on;
    exportgraphics(f, fullfile(out, sprintf('rizado_Iref_%02d.png', round(iref*10))), 'Resolution', 150);
    close(f);
end
fclose(fid);
type(fullfile(out, 'lazo_abierto.txt')); type(fullfile(out, 'rizado.txt'));
end

function pr(fid, varargin)
fprintf(fid, varargin{:}); fprintf(varargin{:});
end

function r = rpc(metodo, params)
body = struct('jsonrpc', '2.0', 'method', metodo, 'params', {params}, 'id', 1);
o = weboptions('MediaType', 'application/json', 'RequestMethod', 'post', 'Timeout', 600, 'ContentType', 'json');
res = webwrite('http://localhost:1080/RPC2', jsonencode(body), o);
if isfield(res, 'error') && ~isempty(res.error), error('%s', jsonencode(res.error)); end
r = res.result;
end

function [A, fase] = fund(x, f, dt)
x = x(:)'; n = numel(x); k = 0:n-1;
a = sum(x .* cos(2*pi*f*k*dt)) * 2 / n;
b = sum(x .* sin(2*pi*f*k*dt)) * 2 / n;
A = hypot(a, b); fase = atan2d(a, b);
end

function d = dI(d, Vdc, L, fsw)
d = min(max(d, 0), 0.5);
d = Vdc * d * (1 - d) / (2 * L * fsw);
end

function m = prom(t, x, ta, tb)
k0 = find(t >= ta, 1, 'first'); k1 = find(t <= tb, 1, 'last');
m = sum(diff(t(k0:k1)) .* (x(k0:k1-1) + x(k0+1:k1)) / 2) / (t(k1) - t(k0));
end

function [tmax, ppmax, tb, pp] = rizado(t, i, ts)
T0 = 0.04; T1 = 0.06;
n = floor((T1 - T0) / ts + 1e-9);
bordes = T0 + (0:n) * ts;
centros = bordes(1:end-1) + ts/2;
medias = arrayfun(@(k) prom(t, i, bordes(k), bordes(k+1)), 1:n);
pp = []; tb = [];
for k = 2:n-1
    idx = find(t >= bordes(k) & t <= bordes(k+1));
    resto = zeros(1, numel(idx));
    for q = 1:numel(idx)
        tj = t(idx(q));
        if tj < centros(k), c = centros(k-1); m0 = medias(k-1); m1 = medias(k);
        else, c = centros(k); m0 = medias(k); m1 = medias(k+1); end
        resto(q) = i(idx(q)) - (m0 + (m1 - m0) * (tj - c) / ts);
    end
    pp(end+1) = max(resto) - min(resto); %#ok<AGROW>
    tb(end+1) = bordes(k); %#ok<AGROW>
end
[ppmax, q] = max(pp); tmax = tb(q);
end

function v = vals(V)
if iscell(V)
    v = cellfun(@(c) c(:)', V, 'UniformOutput', false);
else
    v = cell(1, size(V,1));
    for q = 1:size(V,1), v{q} = V(q,:); end
end
end
