#! /usr/bin/sh

##
# FSL stuff --- not optimized at all.  Just wanted to produce something
# for comparison.  Run flirt and fnirt, the latter with a small number
# of iterations.  Use fsl's applywarp function to warp the image for
# comparison with the converted displacement field used in ANTs
#

referenceImage=S_template3.nii.gz
movingImage=brain.nii.gz
outputFslPrefix=fsl_refxmov

echo "Using flirt..."
echo "  Command: flirt -ref ${referenceImage} -in ${movingImage} -omat ${outputFslPrefix}Affine.mat"
flirt -v -ref ${referenceImage} -in ${movingImage} -omat ${outputFslPrefix}Affine.mat

echo ""
echo ""
echo "Using fnirt..."
echo "  Command: fnirt --ref=${referenceImage} --in=${movingImage} --aff=${outputFslPrefix}Affine.mat --miter=2,0,0,0 --fout=${outputFslPrefix}Warp"
fnirt --ref=${referenceImage} --in=${movingImage} --verbose --aff=${outputFslPrefix}Affine.mat --miter=2,0,0,0 --fout=${outputFslPrefix}Warp

echo ""
echo ""
echo "Using applywarp..."
echo "  Command: applywarp --ref=${referenceImage} --in=${movingImage} --warp=${outputFslPrefix}Warp.nii.gz --out=${outputFslPrefix}Warped.nii.gz"
applywarp -v --ref=${referenceImage} --in=${movingImage} --warp=${outputFslPrefix}Warp.nii.gz --out=${outputFslPrefix}Warped.nii.gz

##
# ANTs and FSL commands to convert the displacement field produced by FSL to
# something usable by ANTs.  This is similar to what is described here:
#
#   https://mrtrix.readthedocs.io/en/latest/spatial_normalisation/warping_images_with_warps_from_other_packages.html
#
# ANTs uses relative displacements (x' = x + dx) so we have to modify the
# workflow a bit.

coordsMovingPrefix=coordinateMovingImage
coordsReferencePrefix=coordinateReferenceImage
displacementPrefix=displacementField
suffixes=( xvec yvec zvec )

echo ""
echo ""
echo "Creating coordinate images in both the warped moving and reference spaces..."
echo "  Command: ImageMath 3 ${coordsMovingPrefix} CoordinateComponentImages $movingImage"
echo "  Command: ImageMath 3 ${coordsReferencePrefix} CoordinateComponentImages $referenceImage"
ImageMath 3 ${coordsMovingPrefix} CoordinateComponentImages $movingImage
ImageMath 3 ${coordsReferencePrefix} CoordinateComponentImages $referenceImage

echo ""
echo ""
echo "Warping moving coordinate images with applywarp..."
for d in {0..2};
  do
    echo "  Command: applywarp --ref=${referenceImage} --in=${coordsMovingPrefix}${d}.nii.gz --warp=${outputFslPrefix}Warp.nii.gz --out=${coordsMovingPrefix}${d}Warped.nii.gz"
    echo "  Command: ImageMath 3 ${displacementPrefix}${suffixes[$d]}.nii.gz - ${coordsMovingPrefix}${d}Warped.nii.gz ${coordsReferencePrefix}${d}.nii.gz"
    applywarp --ref=${referenceImage} --in=${coordsMovingPrefix}${d}.nii.gz --warp=${outputFslPrefix}Warp.nii.gz --out=${coordsMovingPrefix}${d}Warped.nii.gz
    ImageMath 3 ${displacementPrefix}${suffixes[$d]}.nii.gz - ${coordsMovingPrefix}${d}Warped.nii.gz ${coordsReferencePrefix}${d}.nii.gz
  done

outputAntsPrefix=ants_refxmov
echo ""
echo ""
echo "Creating relative warp for ANTs..."
ConvertImage 3 ${displacementPrefix} ${outputAntsPrefix}Warp.nii.gz 9

echo ""
echo ""
echo "Apply displacement field using ANTs tools..."
antsApplyTransforms -v 1 -d 3 -i ${movingImage} -r ${referenceImage} -o ${outputAntsPrefix}Warped.nii.gz -n linear -t ${outputAntsPrefix}Warp.nii.gz

echo ""
echo ""
echo "Done.  Compare ${outputAntsPrefix}Warped.nii.gz and ${outputFslPrefix}Warped.nii.gz."