  function [phantom, params] = rect_im(ig, params, varargin)
%|function [phantom, params] = rect_im(ig, params, options)
%|
%| generate rectangle phantom image from parameters:
%|	[x_center y_center x_width y_width angle_degrees amplitude]
%|
%| in
%|	ig			image_geom() object
%|	params			rect parameters, if empty, use the default 
%|				params = rect_im_default_parameters(xfov, yfov)
%|
%| options:
%|	'rot'		float	rotate rects by this amount [degrees]
%|	'oversample'	int	oversampling factor, for grayscale boundaries
%|	hu_scale	float	use 1000 to scale shepp-logan to HU (default: 1)
%|
%| out
%|	phantom		[nx ny]	image
%|
%| 2008-08-04, Yong Long, adapted from ellipse_im()
%| Copyright 2006-2-2, Jeff Fessler, University of Michigan

if nargin == 1 && streq(ig, 'test'), rect_im_test, return, end
if nargin < 1, help(mfilename), error(mfilename), end

arg.rot = 0;
arg.oversample = 1;
arg.replace = 0;
arg.hu_scale = 1;
arg.fov = [];
arg = vararg_pair(arg, varargin);
if isempty(arg.fov), arg.fov = ig.fov; end

if ~isvar('params') || isempty(params)
	params = rect_im_default_parameters(arg.fov, arg.fov);
end

params(:,6) = params(:,6) * arg.hu_scale;

% optional rotation
if arg.rot ~= 0
	th = deg2rad(arg.rot);
	cx = params(:,1);
	cy = params(:,2);
	params(:,1) = cx * cos(th) + cy * sin(th);
	params(:,2) = -cx * sin(th) + cy * cos(th);
	params(:,5) = params(:,5) + rot;
	clear x y
end

do_fast = params(:,5) == 0; % non-rotated ones are faster

if any(do_fast)
	phantom = rect_im_fast(params(do_fast,:), ...
		ig.nx, ig.ny, ig.dx, ig.dy, ig.offset_x, ig.offset_y, ...
		arg.replace);
else
	phantom = 0;
end

if any(~do_fast)
	phantom = phantom + rect_im_do(params(~do_fast,:), ...
		ig.nx, ig.ny, ig.dx, ig.dy, ig.offset_x, ig.offset_y, ...
		arg.oversample, arg.replace);
end


%
% rect_im_fast()
% fast version with no over-sampling for non-rotated rectangles
%
function phantom = rect_im_fast(params, ...
	nx, ny, dx, dy, offset_x, offset_y, replace)

if size(params,2) ~= 6
	error 'bad rect parameter vector size'
end

phantom = zeros(nx, ny);

wx = (nx-1)/2 + offset_x;
wy = (ny-1)/2 + offset_y;
x1 = ([0:nx-1]' - wx) * dx; % col
y1 = ([0:ny-1] - wy) * dy; % row

fun = @(x1, x2, wx) ... % integrated rect function
	(max(x2 + wx/2, 0) - max(x2 - wx/2, 0)) - ...
	(max(x1 + wx/2, 0) - max(x1 - wx/2, 0));

%ticker reset
ne = nrow(params);
for ie = 1:ne
%	ticker(mfilename, ie, ne)

	rect = params(ie, :);
	cx = rect(1);	wx = rect(3);
	cy = rect(2);	wy = rect(4);
	theta = deg2rad(rect(5));
	if theta ~= 0, fail 'theta=0 required', end
	x = x1 - cx;
	y = y1 - cy;
	tx = fun(x-abs(dx)/2, x+abs(dx)/2, wx);
	ty = fun(y-abs(dy)/2, y+abs(dy)/2, wy);
	tmp = single(tx) * single(ty); % outer product (separable)
	if replace
		phantom(tmp > 0) = rect(6);
	else
		phantom = phantom + rect(6) * tmp;
	end
end



%
% rect_im_do()
%
function phantom = rect_im_do(params, ...
	nx, ny, dx, dy, offset_x, offset_y, over, replace)

if size(params,2) ~= 6
	error 'bad rect parameter vector size'
end

phantom = zeros(nx*over, ny*over);

wx = (nx*over-1)/2 + offset_x*over;
wy = (ny*over-1)/2 + offset_y*over;
xx = ([0:nx*over-1] - wx) * dx / over;
yy = ([0:ny*over-1] - wy) * dy / over;
[xx yy] = ndgrid(xx, yy);

ticker reset
ne = nrow(params);
for ie = 1:ne
	ticker(mfilename, ie, ne)

	rect = params(ie, :);
	cx = rect(1);	wx = rect(3);
	cy = rect(2);	wy = rect(4);
	theta = deg2rad(rect(5));
	x = cos(theta) * (xx-cx) + sin(theta) * (yy-cy);
	y = -sin(theta) * (xx-cx) + cos(theta) * (yy-cy);
	tmp = abs(x / wx) < 1/2 & abs(y / wy) < 1/2;
	if replace
		phantom(tmp > 0) = rect(6);
	else
		phantom = phantom + rect(6) * tmp;
	end
end

phantom = downsample2(phantom, over);


%
% default params for rectangles
% the first four columns are unitless for fov=64
%
function params = rect_im_default_parameters(xfov, yfov)
f = 1/64;
params = [ ...
	0	0	50	50	0	1
	10	-16	25	16	0	-0.5
	-13	15	13	13	1*45	1
...
	-18	0	1	1	0	1
	-12	0	1	1	0	1
	-6	0	1	1	0	1
	0	0	1	1	0	1
	6	0	1	1	0	1
	12	0	1	1	0	1
	18	0	1	1	0	1
];

params(:,[1 3]) = params(:,[1 3]) * xfov / 64;
params(:,[2 4]) = params(:,[2 4]) * yfov / 64;


% rect_im_test()
function rect_im_test
ig = image_geom('nx', 2^8, 'ny', 2^8, 'fov', 256);
pic = rect_im(ig, [], 'oversample', 3);
%unique(pic)
im(ig.x, ig.y, pic, 'default rects'), cbar
