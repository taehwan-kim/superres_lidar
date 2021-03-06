% Script to perform super-resolution of spikes from low frequency
% measurements. More specifically, the locations of the nonzeros components 
% of x are determined from measurements of the form y=Fx where F is the low 
% pass operator that maps a function in the unit interval to its 2fc+1 lower
% Fourier series coefficients. Recovery is carried out by solving:
% 
% max_u Re(y'u) - \delta || u ||_2
% subject to max_ j |( F*u )_j | <= 1
% 
% using an equivalent SDP formulation. The script uses CVX
% (http://cvxr.com/cvx/).
%
% For more information see the paper "Super-resolution from noisy data" 
% by E. Candes and C. Fernandez-Granda. 
% Author: Carlos Fernandez-Granda 
% Email: cfgranda@stanford.edu

clear all;
close all;

% Random seed fixed so that the example is the same as in the paper
rand('state',2013);
randn('state',2013);

% cutoff frequency
fc = 40;
jitter_factor = 10;
jitter_ratio = 0.5;
distance = 2/fc;

% number of spikes
nspikes=14;

jitter = distance/jitter_factor;
tspikes_aux = ( (distance/2) : distance : (nspikes+1)*distance )';
offsets = cumsum(jitter.*rand(nspikes,1).*(rand(nspikes,1)<jitter_ratio));
tspikes = 0.2+tspikes_aux(1:nspikes) + offsets;
k = -fc:1:fc;
n=2*fc+1;

% amplitudes 
x = randn(nspikes,1)./sqrt(n);

% data 
F = exp(-1i*2*pi*k'*tspikes'); % Fourier matrix
y = F*x; 
% noise variance
sigma=0.02;
z =sigma * randn(n,1);
y=z+y;
SNR = 20 * log10(norm(y)/norm(z));

delta_noise = sqrt(n + sqrt(2*n))*sigma; % good approximation of norm(z)

% Solve SDP
cvx_solver sdpt3
cvx_precision best
cvx_begin sdp quiet
    variable X(n+1,n+1) hermitian;
    X >= 0;
    X(n+1,n+1) == 1;
    trace(X) == 2;
    for j = 1:n-1,
        sum(diag(X,j)) == X(n+1-j,n+1);
    end
    maximize(real(X(1:n,n+1)'*y)-norm(X(1:n,n+1))*delta_noise)
cvx_end
dual_op=cvx_optval;
u = X(1:n,n+1);
aux_u =- conv(u,flipud(conj(u)));

aux_u(2*fc+1)=1+aux_u(2*fc+1);
roots_pol = roots(flipud(aux_u));
% Isolate roots on the unit circle
roots_detected = roots_pol(abs(1-abs(roots_pol)) < 1e-4);
[auxsort,ind_sort]=sort(real(roots_detected));
roots_detected = roots_detected(ind_sort);
% Roots are double so take 1 out of 2 and compute argument
t_rec_roots = angle(roots_detected(1:2:end))/2/pi;
% Argument is between -1/2 and 1/2 so convert angles
t_rec_roots(t_rec_roots < 0)= t_rec_roots(t_rec_roots < 0) + 1;  
t_rec_roots=sort(t_rec_roots);

% solve primal problem to check duality gap and primal support
F_est = exp(-1i*2*pi*k'*t_rec_roots')./sqrt(n); % estimated Fourier matrix
length_est=length(t_rec_roots);
cvx_solver sedumi
cvx_precision best
cvx_begin quiet
    variable x_est_aux(length_est,1) complex;
    minimize(norm(x_est_aux,1))
    subject to 
        norm(y-sqrt(n)*F_est*x_est_aux,2)<=delta_noise
cvx_end
x_est_aux = sqrt(n)*x_est_aux;
primal_op=cvx_optval;
duality_gap = primal_op - dual_op;
thresh_support = 1e-4;
t_est = t_rec_roots(abs(x_est_aux)>thresh_support);
% debias estimate
F_est_debias = exp(-1i*2*pi*k'*t_est'); % estimated Fourier matrix
x_est =  F_est_debias\y;

% plot results
t = linspace(0,1,1e4);
low_res= (y.')* exp(1i*2*pi*k'*t)./n;
low_res_clean= ((F*x).')* exp(1i*2*pi*k'*t)./n;

linewidth=2;

figure
plot(t,real(low_res),'b','LineWidth',linewidth)
hold on
plot(t,real(low_res_clean),'--k','LineWidth',linewidth)
%plot(t,real(low_res_clean),'g','LineWidth',linewidth)
stem(tspikes,real(x),'r','marker','none','LineWidth',linewidth)
%auxplot=-0.5:0.1:0.5;
%for t_j = tspikes
%    plot(t_j*ones(1,length(auxplot)),auxplot,'--k','LineWidth',linewidth)
%end
hold off
%legend('Measurements','Low-res signal','High-res signal')
legend('Noisy measurements','Low-res signal','High-res signal','Location','SouthWest')
xlim([0.43 0.55])
ylim([-0.03 0.025])
set(gca,'FontSize',18) ;
set(gca,'xtick',[])
set(gca,'xticklabel',[])
set(gca,'ytick',[])
set(gca,'yticklabel',[])

markersize=7;
linewidth=2;
figure
%stem(tspikes,real(x),'fill','or','MarkerSize',markersize,'LineWidth',linewidth)
stem(tspikes,real(x),'r','marker','none','LineWidth',2.5)
%stem(tspikes,real(x),'r','marker','none','LineWidth',linewidth)
%plot(tspikes,real(x),'ob','MarkerSize',markersize)
hold on
stem(t_est,real(x_est),'--xb','MarkerSize',markersize,'LineWidth',linewidth)
%stem(t_est,imag(x_est),'--xg','MarkerSize',markersize+2,'LineWidth',linewidth)
%stem(t_est,real(x_est),'--b','marker','none','LineWidth',linewidth)
%plot(t_est,real(x_est),'xr','MarkerSize',markersize)
legend('High-res Signal','Estimate ','Location','NorthWest')
hold off
xlim([0.08 0.974])
ylim([-0.13 0.185])
set(gca,'FontSize',18) ;
set(gca,'xtick',[])
set(gca,'xticklabel',[])
set(gca,'ytick',[])
set(gca,'yticklabel',[])

print -f1 -depsc lowres_spikes.eps
print -f2 -depsc estimate.eps