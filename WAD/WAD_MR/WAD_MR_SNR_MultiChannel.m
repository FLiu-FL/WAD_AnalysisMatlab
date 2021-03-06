% ------------------------------------------------------------------------
% WAD_MR is an MRI analysis module written for IQC.
% NVKF WAD IQC software is a framework for automatic analysis of DICOM objects.
% 
% Copyright 2012-2013  Joost Kuijer / jpa.kuijer@vumc.nl
% 
% 
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.
% ------------------------------------------------------------------------

function WAD_MR_SNR_MultiChannel( i_iSeries, sSeries, sParams )
% Evaluate SNR on uncombined images of the central slice
%
% Related config entries:
% - combinedImage
%
% ------------------------------------------------------------------------
% SQVID MR
% file: WAD_MR_SNR
% 
% ------------------------------------------------------------------------
% VUmc, Amsterdam, NL / Joost Kuijer / jpa.kuijer@vumc.nl
% 2008-10-24 / JK
% first version
% ------------------------------------------------------------------------
% 2012-08-13 / JK
% adapted to WAD
% ------------------------------------------------------------------------
% 2016-10-21 / JK
% Support multislice acquisition for multichannel coil SNR
% Implemented by new parameter <uncombineImage> to allow configuration of
% the instance numbers of the separate coil images.
% 	<params>
% 	    <combinedImage>63</combinedImage>
% 	    <uncombinedImage> <image>55</image> <coil>1</coil> </uncombinedImage>
% 	    <uncombinedImage> <image>56</image> <coil>2</coil> </uncombinedImage>
% 	    <uncombinedImage> <image>57</image> <coil>3</coil> </uncombinedImage>
% 	    <uncombinedImage> <image>58</image> <coil>4</coil> </uncombinedImage>
% 	    <uncombinedImage> <image>59</image> <coil>5</coil> </uncombinedImage>
% 	    <uncombinedImage> <image>60</image> <coil>6</coil> </uncombinedImage>
% 	    <uncombinedImage> <image>61</image> <coil>7</coil> </uncombinedImage>
% 	    <uncombinedImage> <image>62</image> <coil>8</coil> </uncombinedImage>
%	</params>
% ------------------------------------------------------------------------
% 2017-01-05 / JK
% bugfix for combined image in separate series.
% ------------------------------------------------------------------------


% produce a figure on the screen or be quiet...
quiet = true;
isInteractive = false;


% ----------------------
% GLOBALS
% ----------------------
global WAD

% version info
my.name = 'WAD_MR_SNR_MultiChannel';
my.version = '1.2.2';
my.date = '20170105';
WAD_vbprint( ['Module ' my.name ' Version ' my.version ' (' my.date ')'] );


% security check: is current series an uncombined coils series?
if length( sSeries.instance ) == 1
    WAD_vbprint( [my.name ': Only 1 image in series. Skipping analysis.'] );
    return;
end


% ---------------------------------------------
% check image order / combined coils image
% ---------------------------------------------
% combined coils image needs to be configured, there is no default...
if ~isfield( sParams, 'combinedImage' ) || isequal( sParams.combinedImage, [] )
    % can't do analysis
    WAD_vbprint( [my.name ': Parameter "combinedImage" is not defined. Skipping analysis.'] );
    return
end

% ---------------------------------------------
% parse the config...
% ---------------------------------------------
inum = sParams.combinedImage;
% handle specials...
if isequal( inum, WAD.const.inNextSeries ) 
    % -----------------------
    % find the next series...
    % -----------------------
    foundNextSeries = false;
    curStudy = WAD.in.patient(1).study(1);
    i_nSeries = length( curStudy.series );
    for ii = 1:i_nSeries
        if ( curStudy.series( ii ).number == sSeries.number + 1 )
            sCCSeries = curStudy.series( ii );
            foundNextSeries = true;
            break;
        end
    end
    if ~foundNextSeries
        WAD_vbprint( [my.name ': Error: could not find next series for combined coils image.'] );
        myErrordlg( isInteractive, 'Cannot find find next series for combined coils image.', 'WAD_MR_SNR_MultiChannel', 'on' );
        return
    end
    % combined coils series should have only one image and same series
    % description as current series
    % if next series belongs to this one, it should have same name, and just one image.
    if ~strcmp( sSeries.description, sCCSeries.description ) || length( sCCSeries.instance ) ~= 1
        WAD_vbprint( [my.name ': ERROR: combined coils image is in next series, it doesn''t have same series description or doesn''t have 1 image. Skip analysis'] );
        return
    end
    % combined coils number
    inum = 1;
else
    % combined coil image in current series
    sCCSeries = sSeries;
    if isequal( inum, WAD.const.firstInSeries )
        inum = 1;
    elseif isequal( inum, WAD.const.lastInSeries )
        inum = length( sSeries.instance );
    end
end

% ---------------------------------------------
% find the image (array order can be different from instance numbering)
% ---------------------------------------------
foundImage = false;
for ii = 1:length( sSeries.instance )
    if ( sSeries.instance(ii).number == inum )
        ci = ii;
        foundImage = true;
        break;
    end
end
if ~foundImage
    WAD_vbprint( [my.name ': Error: could not find configured combined coils image.'] );
    myErrordlg( isInteractive, 'Cannot find configured combined coils image.', 'WAD_MR_SNR_MultiChannel', 'on' );
    return
end


% check if uncombinedImage is configured
isConfiguredUncombinedImages = false;
hasConfiguredUncombinedCoils = false;
if isfield( sParams, 'uncombinedImage' ) && ~isempty( sParams.uncombinedImage )
    % find elements: image and coil
    if isfield( sParams.uncombinedImage, 'image' ) && ~isempty( [sParams.uncombinedImage.image] )
        uncombinedImage = [sParams.uncombinedImage.image];
        WAD_vbprint( [my.name ': Found configured uncombinedImage = ' num2str( uncombinedImage )] );
        isConfiguredUncombinedImages = true;
    end
    if isfield( sParams.uncombinedImage, 'coil' ) && ~isempty( [sParams.uncombinedImage.coil] )
        uncombinedCoil = [sParams.uncombinedImage.coil];
        WAD_vbprint( [my.name ': Found configured uncombinedCoil = ' num2str( uncombinedCoil )] );
        hasConfiguredUncombinedCoils = true;
    end
end


% do the evaluation...
WAD_vbprint( [my.name ': Calculating centre coordinates on combined coils image #' num2str( inum )] );

if ~isfield( sParams, 'interpolPower' ) || isempty( sParams.interpolPower )
    sParams.interpolPower = 0; % no interpolation for calculation of centre of phantom
end
WAD_vbprint( [my.name ':   Interpolation set to 2 ^ ' num2str(sParams.interpolPower) '. This is configurable in <params> <interpolPower>' ] );

% SNR needs the centre coordinates, which are calculated by SQ_MR_geomXY
[diameter_pix, centre_pix] = WAD_MR_privateSizePos_pix( sCCSeries.instance(ci), sParams, quiet );
WAD_vbprint( [my.name ': Centre location at ' num2str(centre_pix)] );

% configured parameters for ROI's
% SNR needs distance of background ROI's from phantom centre
if ~isfield( sParams, 'backgroundROIshift' ) || isempty( sParams.backgroundROIshift )
    % no ROI shift configured, use default
    sParams.backgroundROIshift = WAD.const.defaultBackgroundRoiShift;
    WAD_vbprint( [my.name ':   No parameter <backgroundROIshift> configured, using default value = ' num2str(sParams.backgroundROIshift) ' mm'] );
end
WAD_vbprint( [my.name ':   Configured ROI shift = ' num2str(sParams.backgroundROIshift) ' mm'] );

if ~isfield( sParams, 'ROIradius' ) || isempty( sParams.ROIradius )
    % no ROI radius configured, use default
    sParams.ROIradius = WAD.const.defaultRoiRadius;
    WAD_vbprint( [my.name ':   No parameter <ROIradius> configured, using default value = ' num2str(sParams.ROIradius) ' mm'] );
end
WAD_vbprint( [my.name ':   Configured ROI radius = ' num2str(sParams.ROIradius) ' mm'] );

if ~isfield( sParams, 'backgroundROIsize' ) || isempty( sParams.backgroundROIsize )
    % no ROI radius configured, use default
    sParams.backgroundROIsize = WAD.const.defaultBackgroundRoiSize;
    WAD_vbprint( [my.name ':   No parameter <backgroundROIsize> configured, using default value = ' num2str(sParams.backgroundROIsize) ' mm'] );
end
WAD_vbprint( [my.name ':   Configured ROI radius = ' num2str(sParams.backgroundROIsize) ' mm'] );


% copy combined image number
cinum = inum;

% display waitbar in interactive mode
if isInteractive, h = waitbar( 0, 'Calculating SNR...' ); end

% number of images in series
ninum = length( sSeries.instance );



% if all images have the same image number (Siemens VB25 and earlier), renumber them now
% check if first and last image have the same number
if sSeries.instance(1).number == sSeries.instance(ninum).number
    WAD_vbprint( [my.name ':   Combined coil images have same instance number. Start renumbering.'] );
    % renumber
    for inum = 1:ninum
        sSeries.instance(inum).number = inum;
    end
end

% security check: images needs to have the same slice position. Check first
% and last image... note: not foolproof but checking all slices takes a
% long time.
% info1 = dicominfo( sSeries.instance(1).filename );
% info2 = dicominfo( sSeries.instance(ninum).filename );
% 
% if ( info1.SliceLocation ~= info2.SliceLocation )
%     if isInteractive, close(h), end
%     WAD_vbprint( [my.name ':   Error: images for multi-channel SNR must be from single slice location.'] );
%     myErrordlg( isInteractive, 'Images for multi-channel SNR must be from single slice location.', 'SNR MultiChannel', 'on' );
%     return
% end


% now calculate the SNR for all coil images
% loop over uncombined images
% note: if uncombined images are configured these have already been copied to the uncombinedImage array
if ~isConfiguredUncombinedImages
    % all images in series
    uncombinedImage = 1:ninum;
end

% loop over uncombined images
for inum = uncombinedImage
    if isInteractive, waitbar( inum/ninum, h ); end

    % skip the combined image
    if ( sSeries.number == sCCSeries.number ) && ( inum == cinum )
        continue;
    end
    % find the image
    foundImage = false;
    for ii = 1:length( sSeries.instance )
        if ( sSeries.instance(ii).number == inum )
            ci = ii;
            foundImage = true;
            break;
        end
    end
    if ~foundImage
        close(h)
        WAD_vbprint( [my.name ':   Error: could not find coil image #' num2str(inum)] );
        myErrordlg( isInteractive, ['Cannot find coil image #' num2str(inum)], 'SNR MultiChannel', 'on' );
        return;
    end
    
    % get the coil element number
    if hasConfiguredUncombinedCoils
        coil = uncombinedCoil( uncombinedImage == inum );
    else
        coil = inum;
    end
    

    quiet = 1;
    SNR = WAD_MR_privateSNR_ghost( sSeries.instance(ci), centre_pix, sParams, quiet );
    WAD_vbprint( [my.name ':   Coil: ' num2str(coil) '  Image: ' num2str(inum) '  SNR = ' num2str(SNR) ] );
    
    % factor 0.655 corrects for reduced noise in background of magnitude image.
    % See Henkelman.
    SNR_henk = SNR * 0.655;

    % write the results
    if inum == 1
        WAD_resultsAppendString( 2, ['Multichannel SNR on series: ' num2str(sSeries.number)], 'SNR multi-channel' );
    end
    % TO DO: how to handle action limits for MC coils...?
    WAD_resultsAppendFloat( 1, SNR_henk, 'SNR', [], ['Coil ' num2str(coil)] );
end

% close waitbar in interactive mode
if isInteractive, close(h), end

return
