% ------------------------------------------------------------------------
% This WAD folder provides a "library" of helper functions written for IQC.
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

function WAD_findMatchingSeries( theStudy, theAction )
% - Find DICOM series that match the configured criteria
% - Run the configured action
%
% ------------------------------------------------------------------------
% WAD MR
% file: WAD_findMatchingSeries
%
% ------------------------------------------------------------------------
% VUmc, Amsterdam, NL / Joost Kuijer / jpa.kuijer@vumc.nl
% 2012-11-06 / JK
% first WAD version named 0.95 converted from SQVID 0.95
% ------------------------------------------------------------------------


% ----------------------
% GLOBALS
% ----------------------
%global WAD


% version info
my.name = 'WAD_findMatchingSeries';
my.version = '0.95';
my.date = '20121106';
WAD_vbprint( ['Module ' my.name ' Version ' my.version ' (' my.date ')'], 2 );


% ----------------------
% try to find series that matches with current action
% ----------------------
% loop over image series
i_nSeries = length( theStudy.series );
for i_icSeries = 1:i_nSeries
    WAD_vbprint( [my.name ': try a match with series ' num2str(i_icSeries) ], 2 )
    curSeries = theStudy.series( i_icSeries );
    i_iDcmSeries = curSeries.number;
    WAD_vbprint( [my.name ': --> DICOM series ' num2str(i_iDcmSeries) ' "' theStudy.series( i_icSeries ).description '"' ], 2 );

    % ----------------------
    % loop over fields to match for current action
    % ----------------------
    bMatch = false; % programming safety: if we forget to set bMatch in some case...
    i_nMatch = length( theAction.match );
    for i_icMatch = 1:i_nMatch
        % theAction.match is now always cell or struct
        if iscell( theAction.match )
            curMatch = theAction.match{ i_icMatch };
        else
            curMatch = theAction.match( i_icMatch );
        end

        switch curMatch.ATTRIBUTE.type
            case 'DCM4CHEE'
                switch curMatch.ATTRIBUTE.field
                    case 'SeriesDescription'
                        bMatch = matchSeriesDescription( curMatch, curSeries );
                        if ~bMatch, break; end % break from match loop
                    case 'ImagesInSeries'
                        bMatch = matchImagesInSeries( curMatch, curSeries );
                        if ~bMatch, break; end % break from match loop                    
                    otherwise
                        % should not happen...
                        WAD_vbprint( [my.name ': Unexpected field content in switch/case for match type "DCM4CHEE".'], 1 );
                        bMatch = false; break; % break from match loop 
                end % switch field
            case 'DICOM'
                bMatch = matchDicomTag( curMatch, curSeries );
                if ~bMatch, break; end % break from match loop                    
            otherwise
                WAD_vbprint( [my.name ': Unexpected type content in matching switch/case.'], 1 );
                bMatch = false; break % break from match loop
        end % switch type
    end % loop over matches

    % if we're here: all matches were positive
    if bMatch
        % we have a match!
        WAD_vbprint( [my.name ': match!'], 2 );

        % go run the action
        WAD_vbprint( [my.name ': Run action ' theAction.name ' on series ' num2str(i_icSeries) ' (DICOM series ' num2str(i_iDcmSeries) ' "' theStudy.series( i_icSeries ).description '")'], 1 );
        try
            % use the constructed function handle to call the fuction
            % function declaration must match: actionName( seriesNumber, seriesStruct, paramStruct, limitsStruct )
            theAction.fh( i_icSeries, theStudy.series( i_icSeries ), theAction.params, theAction.limits );
        catch err
            WAD_ErrorMsg( my.name, ['ERROR running action ' theAction.name ' on series ' num2str(i_icSeries) ' (DICOM series ' num2str(i_iDcmSeries) ' "' theStudy.series( i_icSeries ).description '")'], err );
        end % try / catch
    end % if bMatch
end % loop over series



% ------------------------------------------------------------------------
% Matching functions
% ------------------------------------------------------------------------
function bMatch = matchSeriesDescription( curMatch, curSeries )
my.name = 'WAD_MR_runConfiguredAnalysis:matchSeriesDescription';
% compare action content with series description
bMatch = isequal( curSeries.description, curMatch.CONTENT );
WAD_vbprint( [my.name ': Compare SeriesDescription "' curSeries.description '" with "' curMatch.CONTENT '" Equal? >> ' num2str(bMatch) ], 2 );


function bMatch = matchImagesInSeries( curMatch, curSeries )
my.name = 'WAD_MR_runConfiguredAnalysis:matchImagesInSeries';
% compare action content with number of images
bMatch = isequal( length( curSeries.instance ), curMatch.CONTENT );
WAD_vbprint( [my.name ': Compare #images ' num2str( length( curSeries.instance ) ) ' with ' num2str( curMatch.CONTENT ) '. Equal? >> ' num2str(bMatch) ], 2 );


function bMatch = matchDicomTag( curMatch, curSeries )
my.name = 'WAD_MR_runConfiguredAnalysis:matchDicomTag';
% compare action content with DICOM field
try
    % read DICOM header of first instance
    WAD_vbprint( [my.name ': Reading DICOM file "' curSeries.instance(1).filename '"'], 2 );
    dcminfo = dicominfo( curSeries.instance(1).filename );
catch err
    WAD_vbprint( [my.name ': Error reading DICOM file "' curSeries.instance(1).filename '"'], 1 );
    WAD_vbprint( [my.name ': ' err.message ] );
end

% check if configured field exists
dcmFieldName = curMatch.ATTRIBUTE.field;
if isfield( dcminfo, dcmFieldName )
    % compare action content with DICOM field
    % statement below should work for both number and string type fields
    bMatch = isequal( dcminfo.(dcmFieldName), curMatch.CONTENT );
    WAD_vbprint( [my.name ': Compare DICOM field "' dcmFieldName '" content "' dcminfo.(dcmFieldName) '" with "' curMatch.CONTENT '" Equal? >> ' num2str(bMatch) ], 2 );
else
    bMatch = false;
    WAD_vbprint( [my.name ': DICOM field "' dcmFieldName '" is not defined.'], 2 );
end