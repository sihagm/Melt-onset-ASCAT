clear all;

%% Important: To use this code, the Matlab SIR functions are needed, you can download them here: https://ch.mathworks.com/matlabcentral/fileexchange/3320-sir-file-format-utilities
%% Download ASCAT images: https://www.scp.byu.edu/data/Ascat/SIR/Ascat_sir.html
ScriptDir = 'D:\Desktop\github\ASCAT\';
cd(ScriptDir)

refdir = 'D:\Desktop\github\ASCAT\2018\ref\'; %the reference folder should contain several scenes of dry snow/ice conditions - I took all the scenes from Jan and Feb
DataDir = 'D:\Desktop\github\ASCAT\2018\';
SaveDir = 'D:\Desktop\github\ASCAT\2018\';

cd(SaveDir);
sfx = 'sir';
list_Imgs = dir(fullfile(DataDir, ['*.' sfx])); % list available images
ref_Imgs = dir(fullfile(refdir, ['*.' sfx]));
numberofscenes = length(ref_Imgs);
%%
%% make ref scene out of many scenes
[I0, REFhead, descrip, iaopt] = loadsir([refdir ref_Imgs(1).name]);
sumImage = single(I0);

for i=1:length(ref_Imgs)
    imR = loadsir([refdir ref_Imgs(i).name]);
    sumImage = sumImage + single(imR);
end
      ref2 = sumImage/(numberofscenes);
      REF_dB = ref2;
      
 clear imR sumImage ref_Imgs ref2 numberofscenes I0 descrip iaopt
%% Watermask product, can also be downloaded where the ASCAT images are, at the bottom of the webpage
water = loadsir('D:\Desktop\github\ASCAT\que-Arc.sir.lmask');
%%% water=0, land=1
  
water = single(water);
water2 = single(imcomplement(water));
%% get coordinates
x = 1:1530;
y = 1:1530;
y = y';
[lon, lat]=pixtolatlon(x,y,REFhead);

clear REFhead;
clear x;
clear y;

%% Melt Onset
%% datacube ASCAT
% Create a datacube containing all the wet snow/ice binary images
im_datacubeASCAT = zeros(size(water,1),size(water,2),length(list_Imgs)); % build empty datacube
index = 1;
for i=1:length(list_Imgs)
    
    im = loadsir([DataDir list_Imgs(i).name]);
    im(im == -33) = nan;
    im(isnan(im))= 10^4;
    
    diff = single(im - REF_dB); %create the ratio images, where a cold snow reference image is subtracted from every image of the year
    diff(diff>20) = 0;
    diff(diff<-50) = 0;
    
%   imASCAT = abs(imASCAT);
    imASCATland = diff.*water; % water and land should be seperated, because different thresholds are suitable
    imASCATland = single(imASCATland<=-1.5); %every pixel with a lower ratio than 1.5 is considered wet snow/ice
    
    imASCATice = diff.*water2;
    imASCATice = single(imASCATice<=-5); %threshold for sea ice
    imASCAT = imASCATland+imASCATice;
                                         
        im_datacubeASCAT(:,:,index) = single(imASCAT);

        index = index+1;
end
im_datacubeASCAT = single(im_datacubeASCAT(:,:,1:index-1));

clear im diff imASCATland imASCATice imASCAT list_Imgs REF_dB
%% onset
[maxvalASCATonset,firstNonZeroASCAT] = max(im_datacubeASCAT ~= 0, [], 3); %find the first date the pixel is considered wet snow/ice
firstNonZeroASCAT(~maxvalASCATonset) = 0; %set no onset found to zero
firstNonZeroASCAT = firstNonZeroASCAT;
firstNonZeroASCAT(firstNonZeroASCAT>270) = 0;
%%  Display the result

f = figure;
       set (gcf, 'PaperPositionMode', 'manual','PaperPosition',[0 0 30 30]);
       worldmap([60 90], [-180 180]);
    h=pcolorm(lat,lon,firstNonZeroASCAT);
    h = flipud(jet(256));
    h(1, :) = [1,1,1];
       colormap(h);
       k=colorbar;
       ylabel(k, 'DOY')
       xlabel('longitude [°]','fontsize', 20);
       ylabel('latitude [°]','fontsize', 20);
       title('ASCAT_MeltOnset_2018', 'Interpreter', 'none', 'fontname', 'Courier', 'fontsize', 14);%%%%%%%%%%%%%      
    fileName = 'ASCAT_onset_2018.jpg'; %%%%%%%%%%%%%
    saveas(f,fileName);
    
 %% Write the result as a geotiff
cellsize = 0.1;
[Z, refvec] = geoloc2grid(lat, lon, double(firstNonZeroASCAT), cellsize);
R = refvecToGeoRasterReference(refvec,size(Z));
fileName2 = 'ASCAT_onset_2018.tif'; %%%%%%%%%%%%%
geotiffwrite(fileName2, Z, R);      