//
//  RORegistration.m
//  BARTApplication
//
//  Created by Oliver Zscheyge on 8/23/11.
//  Copyright (c) 2011 MPI Cognitive and Human Brain Sciences Leipzig. All rights reserved.
//

#include <assert.h>

#import "RORegistration.h"

#import "EDDataElement.h"
#import "EDDataElementIsis.h"

// ITK
#import <itkImageFileWriter.h>

// Isis
#import "DataStorage/image.hpp"
#import "Adapter/itkAdapter.hpp"



// # Constants # ##
const int NR_THREADS = 16; //8; //4;

const float SMOOTH_FWHM = 1.0f; // in valign3d: defined as 2.0 and overwritten as 1.0 by vnormdata cmdline args
const float PIXEL_DENSITY_DEFAULT = 0.012f; // 1.0f;
const short GRID_SIZE_MINIMUM = 5;
const short NITERATION_DEFAULT = 500; // 500
const short N_BINS_DEFAULT = 50;
const float COARSE_FACTOR_DEFAULT = 1.0f;
const float BSPLINE_BOUND_DEFAULT = 15.0f;
const float ROTATION_SCALE_DEFAULT = -1.0f;
const float TRANSLATION_SCALE_DEFAULT = -1.0f;
const short PREALIGN_PRECISION_DEFAULT = 5;

const unsigned int SHOW_ITERATION_STEP_DEFAULT = 10;
const unsigned int SHOW_ITERATION_STEP_VERBOSE = 1;

const unsigned int MATTES_MUTUAL_SEED = 1;



/** 
 * Wrapper class to simulate either one of two return types
 * of the transform function.
 */
class ITKImageContainer
{
private:
    ITKImage::Pointer   img3D;
    ITKImage4D::Pointer img4D;
public:
    ITKImageContainer(ITKImage::Pointer   img3D) { this->img3D = img3D; this->img4D = NULL;  };
    ITKImageContainer(ITKImage4D::Pointer img4D) { this->img3D = NULL;  this->img4D = img4D; };
    ~ITKImageContainer() { };
    bool is3D() { if (this->img3D.IsNull()) { return false; } else { return true; } };
    bool is4D() { if (this->img4D.IsNull()) { return false; } else { return true; } };
    ITKImage::Pointer   getImg3D() { return this->img3D; };
    ITKImage4D::Pointer getImg4D() { return this->img4D; };
};



@interface RORegistration (privateMethods)

-(DeformationFieldType::Pointer)computeTransform:(ITKImage::Pointer)toAlign 
                                   withReference:(ITKImage::Pointer)ref
                                  transformTypes:(std::vector<int>)transform
                                  optimizerTypes:(std::vector<int>)optimizer
                                        prealign:(BOOL)prealign
                                          smooth:(BOOL)smooth;

-(ITKImageContainer*)transform:(ITKImage::Pointer)toAlign
                  orFunctional:(ITKImage4D::Pointer)toAlignFun
                 withReference:(ITKImage::Pointer)ref 
                transformation:(DeformationFieldType::Pointer)trans 
                    resolution:(std::vector<size_t>)res; 

@end

@implementation RORegistration

-(id)init
{
    if (self = [super init]) {
        // From align3d
        self->registrationFactory = RegistrationFactoryType::New();
        self->tmpConstTransformPointer = NULL;
        
//        isis::data::enable_log<isis::util::DefaultMsgPrint>(isis::info);

    }
    
    return self;    
}


-(id)initFindingTransformFrom:(EDDataElement*)toAlign 
                  toReference:(EDDataElement*)ref
{
    if (self = [self init]) {
//        self->v = [self computeTransform:toAlign withReference:ref];
    }
    
    return self;
}

-(EDDataElement*)normdata:(EDDataElement*)fun
                  anatomy:(EDDataElement*)ana
      anatomicalReference:(EDDataElement*)ref
{
    ITKImage::Pointer   funITK3D = [fun asITKImage];
    ITKImage4D::Pointer funITK4D = [fun asITKImage4D];
    ITKImage::Pointer anaITK = [ana asITKImage];
    ITKImage::Pointer refITK = [ref asITKImage];
    
    std::vector<int> transformTypes;
    std::vector<int> optimizerTypes;
    DeformationFieldType::Pointer trans_ana2fun = [self computeTransform:anaITK 
                                                           withReference:funITK3D
                                                          transformTypes:transformTypes
                                                          optimizerTypes:optimizerTypes 
                                                                prealign:YES
                                                                  smooth:YES];
    
//    std::cout << trans_ana2fun << std::endl;
    
    std::vector<size_t> reso;
    reso.push_back(1);
    ITKImageContainer* transformResult = [self transform:anaITK
                                            orFunctional:NULL
                                           withReference:funITK3D
                                          transformation:trans_ana2fun 
                                              resolution:reso];
    
    
    if (transformResult != NULL) {
        ITKImage::Pointer ana2fun = transformResult->getImg3D();
        free(transformResult);
        
        // TODO: check whether back conversion is really necessary
//        EDDataElement* ana2funBackconv = [ana convertFromITKImage:ana2fun];
//        [ana2funBackconv WriteDataElementToFile:@"/tmp/BARTReg_ana2fun.nii"];
//        ana2fun = [ana2funBackconv asITKImage];
        // TODO END
        
//        typedef itk::ImageFileWriter<ITKImage> ITKWriter;
//        itk::ImageFileWriter<ITKImage>::Pointer imageWriter = ITKWriter::New();
//        imageWriter->SetFileName("/tmp/RORegNormdataWorkflow_ana2fun.nii");
//        imageWriter->SetInput(ana2fun);
//        imageWriter->Update();
        
        transformTypes.push_back(0);
        transformTypes.push_back(1);
        transformTypes.push_back(2);
        optimizerTypes.push_back(0);
        optimizerTypes.push_back(0);
        optimizerTypes.push_back(2);
        std::cout << "!!! mni2fun2mni computeTransform START" << std::endl;
        DeformationFieldType::Pointer trans_ana2ref = [self computeTransform:ana2fun 
                                                               withReference:refITK 
                                                              transformTypes:transformTypes
                                                              optimizerTypes:optimizerTypes 
                                                                    prealign:YES
                                                                      smooth:YES];
        std::cout << "!!! mni2fun2mni computeTransform END" << std::endl;
        
        reso.clear();
        reso.push_back(3);

        std::cout << "!!! mni2fun2mni applying transform START" << std::endl;
        transformResult = [self transform:NULL
                             orFunctional:funITK4D
                            withReference:refITK 
                           transformation:trans_ana2ref 
                               resolution:reso];
        std::cout << "!!! mni2fun2mni applying transform END" << std::endl;
        
        if (transformResult != NULL) {
            ITKImage4D::Pointer ana2fun2mni = transformResult->getImg4D();
            free(transformResult);
            return [fun convertFromITKImage4D:ana2fun2mni];
        }

    }
    
    return nil;
}

//-(EDDataElement*)align:(EDDataElement*)toAlign 
//       beingFunctional:(BOOL)fmri
//         withReference:(EDDataElement*)ref 
//{
//    if (toAlign == nil || ref == nil) {
//        // exception?
//        return nil;
//    }
//    
//    // TODO: replace with method: align :: EDDataElement -> EDDataElement
//    
//    DeformationFieldType::Pointer trans = [self computeTransform:toAlign 
//                                                   withReference:ref];
//    
//    std::vector<size_t> res;
//    res.push_back(1);
//    
//    NSLog(@"### FINISHED COMPUTING TRANSFORM, ALIGNING NOW ###");
//    
//    EDDataElement* transformed = [self transform:toAlign 
//                                   withReference:ref 
//                                  transformation:trans 
//                                      resolution:res 
//                                  functionalData:fmri];
//    
//    return transformed;
//}


-(RORegistration*)combineTransform:(RORegistration*)other
{
    return nil;
}

@end

@implementation RORegistration (privateMethods)

bool verbose = false;

-(DeformationFieldType::Pointer)computeTransform:(ITKImage::Pointer)toAlign 
                                   withReference:(ITKImage::Pointer)ref
                                  transformTypes:(std::vector<int>)transforms
                                  optimizerTypes:(std::vector<int>)optimizers
                                        prealign:(BOOL)prealign
                                          smooth:(BOOL)smooth
{
    self->registrationFactory->Reset();
    
    // Convert data elements to ITK images.
    // ### TODO: redundant
    ITKImage::Pointer fixedImage = ref;
    ITKImage::Pointer movingImage = toAlign;
    
    // ### Lipsia Reinclude START
    if ( smooth ) {
		GaussianFilterType::Pointer fixedGaussianFilterX = GaussianFilterType::New();
		GaussianFilterType::Pointer fixedGaussianFilterY = GaussianFilterType::New();
		GaussianFilterType::Pointer fixedGaussianFilterZ = GaussianFilterType::New();
		fixedGaussianFilterX->SetNumberOfThreads( NR_THREADS );
		fixedGaussianFilterY->SetNumberOfThreads( NR_THREADS );
		fixedGaussianFilterZ->SetNumberOfThreads( NR_THREADS );
		fixedGaussianFilterX->SetInput( fixedImage );
		fixedGaussianFilterY->SetInput( fixedGaussianFilterX->GetOutput() );
		fixedGaussianFilterZ->SetInput( fixedGaussianFilterY->GetOutput() );
		fixedGaussianFilterX->SetDirection( 0 );
		fixedGaussianFilterY->SetDirection( 1 );
		fixedGaussianFilterZ->SetDirection( 2 );
		fixedGaussianFilterX->SetOrder( GaussianFilterType::ZeroOrder );
		fixedGaussianFilterY->SetOrder( GaussianFilterType::ZeroOrder );
		fixedGaussianFilterZ->SetOrder( GaussianFilterType::ZeroOrder );
		fixedGaussianFilterX->SetNormalizeAcrossScale( false );
		fixedGaussianFilterY->SetNormalizeAcrossScale( false );
		fixedGaussianFilterZ->SetNormalizeAcrossScale( false );
		fixedGaussianFilterX->SetSigma( SMOOTH_FWHM );
		fixedGaussianFilterY->SetSigma( SMOOTH_FWHM );
		fixedGaussianFilterZ->SetSigma( SMOOTH_FWHM );
		std::cout << "smoothing the fixed image..." << std::endl;
		fixedGaussianFilterZ->Update();
		fixedImage->DisconnectPipeline();
		fixedImage = fixedGaussianFilterZ->GetOutput();
		GaussianFilterType::Pointer movingGaussianFilterX = GaussianFilterType::New();
		GaussianFilterType::Pointer movingGaussianFilterY = GaussianFilterType::New();
		GaussianFilterType::Pointer movingGaussianFilterZ = GaussianFilterType::New();
		movingGaussianFilterX->SetNumberOfThreads( NR_THREADS );
		movingGaussianFilterY->SetNumberOfThreads( NR_THREADS );
		movingGaussianFilterZ->SetNumberOfThreads( NR_THREADS );
		movingGaussianFilterX->SetInput( movingImage );
		movingGaussianFilterY->SetInput( movingGaussianFilterX->GetOutput() );
		movingGaussianFilterZ->SetInput( movingGaussianFilterY->GetOutput() );
		movingGaussianFilterX->SetDirection( 0 );
		movingGaussianFilterY->SetDirection( 1 );
		movingGaussianFilterZ->SetDirection( 2 );
		movingGaussianFilterX->SetOrder( GaussianFilterType::ZeroOrder );
		movingGaussianFilterY->SetOrder( GaussianFilterType::ZeroOrder );
		movingGaussianFilterZ->SetOrder( GaussianFilterType::ZeroOrder );
		movingGaussianFilterX->SetNormalizeAcrossScale( false );
		movingGaussianFilterY->SetNormalizeAcrossScale( false );
		movingGaussianFilterZ->SetNormalizeAcrossScale( false );
		movingGaussianFilterX->SetSigma( SMOOTH_FWHM );
		movingGaussianFilterY->SetSigma( SMOOTH_FWHM );
		movingGaussianFilterZ->SetSigma( SMOOTH_FWHM );
		std::cout << "smoothing the moving image..." << std::endl;
		movingGaussianFilterZ->Update();
		movingImage->DisconnectPipeline();
		movingImage = movingGaussianFilterZ->GetOutput();
	}

    
    
    MatchingFilterType::Pointer matcher = MatchingFilterType::New();    
    bool histogram_matching = true;
    if( histogram_matching ) {
		matcher->SetNumberOfThreads(NR_THREADS);
		matcher->SetNumberOfHistogramLevels(100);
		matcher->SetNumberOfMatchPoints(30);
		matcher->ThresholdAtMeanIntensityOn();
		matcher->SetReferenceImage(fixedImage);
		matcher->SetInput(movingImage);
		matcher->Update();
		movingImage->DisconnectPipeline();
		movingImage = matcher->GetOutput();
	}
    
    //analyse transform vector
	//transform is the master for determining the number of repetitions
	int repetition = transforms.size(); // = transformType.number
	int bsplineCounter = 0;
    
	if (repetition == 0) {
		repetition = 1;
    }
    
    short transform;
    short optimizer;
    std::vector<int> metrics;
    short metric;
    std::vector<int> interpolators;
    short interpolator;
    std::vector<int> iterations;
    short niteration;
    std::vector<int> gridSizes;
    short gridSize;
    
    // from isisreg3d.cxx:
//    //if no pixel density is specified it will be calculated to achieve a amount of 30000 voxel considered for registration
//	float pixelDens = float( 150000 ) / ( refList.front().getSizeAsVector()[0] * refList.front().getSizeAsVector()[1] * refList.front().getSizeAsVector()[2] ) ;
//	if(pixelDens > 1) { pixelDens=1;}
    
    //now, our version:
    ITKImage::SizeType imSize = fixedImage->GetLargestPossibleRegion().GetSize(); 
    
    float pixelDensity =  150000.0f  / ( static_cast<float>( imSize[0] * imSize[1] * imSize[2] )) ;
    if( 1 < pixelDensity){ 
        pixelDensity = 1;}
        
    //float pixelDensity = 0; // TODO: actually fetch pixel density from somewhere
    if (pixelDensity <= 0 or pixelDensity > 1) {
        pixelDensity = PIXEL_DENSITY_DEFAULT;
    }

    
    for ( int counter = 0; counter < repetition; counter++ ) {
		//transform is the master for determining the number of repetitions
		if ( transforms.size() ) {
			transform = (short) transforms[counter];
		} else {
			transform = 0;
		}
        
		if ((counter + 1) <= optimizers.size() and optimizers.size() > 0 ) {
			optimizer = (short) optimizers[counter];
		} else if ((counter + 1) > optimizers.size() and optimizers.size() > 0 ) {
			optimizer = (short) optimizers[optimizers.size() - 1];
		} else {
			optimizer = 0;
		}
        
		if ((counter + 1) <= metrics.size() and metrics.size() > 0) {
			metric = (short) metrics[counter];
		} else if ((counter + 1) > metrics.size() and metrics.size() > 0) {
			metric = (short) metrics[metrics.size() - 1];
		} else {
			metric = 0;
		}
        
		if ((counter + 1) <= interpolators.size() and interpolators.size() > 0) {
			interpolator = (short) interpolators[counter];
		} else if ((counter + 1) > interpolators.size() and interpolators.size() > 0) {
			interpolator = (short) interpolators[interpolators.size() - 1];
		} else {
			interpolator = 0;
		}
        
		if ((counter + 1) <= iterations.size() and iterations.size() > 0) {
			niteration = (short) iterations[counter];
		} else if ((counter + 1) > iterations.size() and iterations.size() > 0) {
			niteration = (short) iterations[iterations.size() - 1];
		} else {
			niteration = NITERATION_DEFAULT;
		}
        
		if ((bsplineCounter + 1) <= gridSizes.size() and gridSizes.size() > 0) {
			gridSize = (short) gridSizes[bsplineCounter];
		} else if ((bsplineCounter + 1) > gridSizes.size() and gridSizes.size() > 0) {
			gridSize = (short) gridSizes[gridSizes.size() - 1];
		} else {
			gridSize = GRID_SIZE_MINIMUM + 1;
		}
        
		if (transform == 2) {
			bsplineCounter++;
		}
		if( counter > 0) {
			registrationFactory->Reset();
		}
        
        // Check pixel density
		if (pixelDensity >= 1) {
			NSLog(@"metric uses all voxels");
		}
        
		//check grid size
		if (gridSize < GRID_SIZE_MINIMUM) {
			NSLog(@"Warning: grid size has to be at least %d! Setting grid size to %d!", GRID_SIZE_MINIMUM, GRID_SIZE_MINIMUM);
			gridSize = GRID_SIZE_MINIMUM;
		}
        
        if (transform == 2 and optimizer != 2) {
			NSLog(@"It is recommended using the BSpline transform in connection with the LBFGSB optimizer!");
		}
        
		if ((transform != 0 and transform != 4) and optimizer == 1) {
			NSLog(@"Inappropriate combination of transform and optimizer! Setting optimizer to RegularStepGradientDescentOptimizer.");
			optimizer = 0;
		}
        
        
		if (verbose) {
			NSLog(@"Setting up the registration object...");
			NSLog(@" used transform: %d", transform);
			NSLog(@" used metric: %d", metric);
			NSLog(@" used interpolator: %d", interpolator);
			NSLog(@" used optimizer: %d", optimizer);
		}
        
//        self->registrationFactory->SetTransform(RegistrationFactoryType::VersorRigid3DTransform);
//        //    self->registrationFactory->SetTransform(RegistrationFactoryType::AffineTransform); 
//        
//        self->registrationFactory->SetMetric(RegistrationFactoryType::MeanSquareMetric);
//        //    self->registrationFactory->SetMetric(RegistrationFactoryType::NormalizedCorrelationMetric); // very runtime inefficient
//        //    self->registrationFactory->SetMetric(RegistrationFactoryType::MutualInformationHistogramMetric); // even more runtime inefficient
//        self->registrationFactory->SetInterpolator(RegistrationFactoryType::LinearInterpolator);
//        self->registrationFactory->SetOptimizer(RegistrationFactoryType::RegularStepGradientDescentOptimizer);   
        
        //transform setup
        switch (transform) {
            case 0:
                self->registrationFactory->SetTransform( RegistrationFactoryType::VersorRigid3DTransform );
                break;
            case 1:
                self->registrationFactory->SetTransform( RegistrationFactoryType::AffineTransform );
                break;
            case 2:
                self->registrationFactory->SetTransform( RegistrationFactoryType::BSplineDeformableTransform );
                break;
            case 3:
                self->registrationFactory->SetTransform( RegistrationFactoryType::TranslationTransform );
                break;
//            case 4:
//                registrationFactory->SetTransform( RegistrationFactoryType::ScaleTransform );
//                break;
//            case 5:
//                registrationFactory->SetTransform( RegistrationFactoryType::CenteredAffineTransform );
//                break;
            default:
                NSLog(@"Error: Unknown transform!");
                return NULL;
		}
        
        //metric setup
		switch (metric) {
            case 0:
                self->registrationFactory->SetMetric( RegistrationFactoryType::MattesMutualInformationMetric );
                break;
            case 1:
                self->registrationFactory->SetMetric( RegistrationFactoryType::MutualInformationHistogramMetric );
                break;
            case 2:
                self->registrationFactory->SetMetric( RegistrationFactoryType::NormalizedCorrelationMetric );
                break;
            case 3:
                self->registrationFactory->SetMetric( RegistrationFactoryType::MeanSquareMetric );
                break;
            default:
                NSLog(@"Error: Unknown metric!");
                return NULL;
		}
        
		//interpolator setup
		switch (interpolator) {
            case 0:
                self->registrationFactory->SetInterpolator( RegistrationFactoryType::LinearInterpolator );
                break;
            case 1:
                self->registrationFactory->SetInterpolator( RegistrationFactoryType::BSplineInterpolator );
                break;
            case 2:
                self->registrationFactory->SetInterpolator( RegistrationFactoryType::NearestNeighborInterpolator );
                break;
            default:
                NSLog(@"Error: Unknown interpolator!");
                return NULL;
		}
        
		//optimizer setup
		switch (optimizer) {
            case 0:
                self->registrationFactory->SetOptimizer( RegistrationFactoryType::RegularStepGradientDescentOptimizer );
                break;
            case 1:
                self->registrationFactory->SetOptimizer( RegistrationFactoryType::VersorRigidOptimizer );
                break;
            case 2:
                self->registrationFactory->SetOptimizer( RegistrationFactoryType::LBFGSBOptimizer );
                break;
            case 3:
                self->registrationFactory->SetOptimizer( RegistrationFactoryType::AmoebaOptimizer );
                break;
            case 4:
                self->registrationFactory->SetOptimizer( RegistrationFactoryType::PowellOptimizer );
                break;
            default:
                NSLog(@"Unknown optimizer!");
                return NULL;
		}

//        if ( transform_filename_in and counter == 0 ) {
//			initialize_mass = false;
//			initialize_center = false;
//			transformReader->SetFileName( transform_filename_in );
//			transformReader->Update();
//			itk::TransformFileReader::TransformListType *transformList = transformReader->GetTransformList();
//			itk::TransformFileReader::TransformListType::const_iterator ti;
//			ti = transformList->begin();
//			registrationFactory->SetInitialTransform( ( *ti ).GetPointer() );
//		}
		if (prealign) {
			self->registrationFactory->UserOptions.PREALIGN = true;
			self->registrationFactory->UserOptions.PREALIGNPRECISION = 7;
		}
        
		if (counter != 0) {
			self->registrationFactory->UserOptions.PREALIGN = false;
			self->registrationFactory->UserOptions.INITIALIZECENTEROFF = true;
			self->registrationFactory->UserOptions.INITIALIZEMASSOFF = true;
			self->registrationFactory->SetInitialTransform( const_cast<TransformBasePointerType>(self->tmpConstTransformPointer) );
		}

//        if ( mask_filename ) {
//			maskReader->SetFileName( mask_filename );
//			maskReader->Update();
//			mask->SetImage( maskReader->GetOutput() );
//			mask->Update();
//			registrationFactory->SetFixedImageMask( mask );
//		}
//        
//		if ( pointset_filename ) {
//			registrationFactory->UserOptions.LANDMARKINITIALIZE = true;
//			std::ifstream pointSetFile;
//			pointSetFile.open( pointset_filename );
//            
//			if ( pointSetFile.fail() ) {
//				std::cout << "Pointset file " << pointset_filename << " not found!" << std::endl;
//				return EXIT_FAILURE;
//			}
//            
//			LandmarkBasedTransformInitializerType::LandmarkPointContainer fixedPointsContainer;
//			LandmarkBasedTransformInitializerType::LandmarkPointContainer movingPointsContainer;
//			LandmarkBasedTransformInitializerType::LandmarkPointType fixedPoint;
//			LandmarkBasedTransformInitializerType::LandmarkPointType movingPoint;
//			pointSetFile >> fixedPoint;
//			pointSetFile >> movingPoint;
//            
//			while ( !pointSetFile.eof() ) {
//				fixedPointsContainer.push_back( fixedPoint );
//				movingPointsContainer.push_back( movingPoint );
//				pointSetFile >> fixedPoint;
//				pointSetFile >> movingPoint;
//			}
//            
//			registrationFactory->SetFixedPointContainer( fixedPointsContainer );
//			registrationFactory->SetMovingPointContainer( movingPointsContainer );
//		}
        
        self->registrationFactory->UserOptions.CoarseFactor = COARSE_FACTOR_DEFAULT;
        self->registrationFactory->UserOptions.BSplineBound = BSPLINE_BOUND_DEFAULT;
        self->registrationFactory->UserOptions.NumberOfIterations = niteration; // Default values: 1. run 500, 2. run 500, 3. run 100
        self->registrationFactory->UserOptions.NumberOfBins = N_BINS_DEFAULT;
        self->registrationFactory->UserOptions.PixelDensity = pixelDensity;
        self->registrationFactory->UserOptions.BSplineGridSize = gridSize;
        self->registrationFactory->UserOptions.ROTATIONSCALE = ROTATION_SCALE_DEFAULT;
        self->registrationFactory->UserOptions.TRANSLATIONSCALE = TRANSLATION_SCALE_DEFAULT;
        self->registrationFactory->UserOptions.PREALIGNPRECISION = PREALIGN_PRECISION_DEFAULT;
        
        // TODO: remove
        if (verbose) {
            registrationFactory->UserOptions.SHOWITERATIONATSTEP = SHOW_ITERATION_STEP_VERBOSE;
            registrationFactory->UserOptions.PRINTRESULTS = true;
        } else {
            registrationFactory->UserOptions.SHOWITERATIONATSTEP = SHOW_ITERATION_STEP_DEFAULT;
            registrationFactory->UserOptions.PRINTRESULTS = false;
        }
        // remove END
//        registrationFactory->UserOptions.PRINTRESULTS = false;
        
        self->registrationFactory->UserOptions.NumberOfThreads = NR_THREADS;
        self->registrationFactory->UserOptions.MattesMutualInitializeSeed = MATTES_MUTUAL_SEED;

//        if ( !initialize_center ) registrationFactory->UserOptions.INITIALIZECENTEROFF = true;
//		if ( !initialize_mass ) registrationFactory->UserOptions.INITIALIZEMASSOFF = true;
        self->registrationFactory->UserOptions.INITIALIZECENTEROFF = true;
        self->registrationFactory->UserOptions.INITIALIZEMASSOFF = true;
        
        self->registrationFactory->SetFixedImage(fixedImage);
        self->registrationFactory->SetMovingImage(movingImage);

        std::cout << std::endl;
		std::cout << "starting the registration... (step " << counter + 1 << " of " << repetition << ")" << std::endl;
		self->registrationFactory->StartRegistration();
        std::cout << "...finished the registration (step " << counter + 1 << " of " << repetition << ")" << std::endl;
        
		std::cout << std::endl;
        
//        if (!use_inverse) {
        self->tmpConstTransformPointer = self->registrationFactory->GetTransform();
//        }
        std::cout << "set tmpConstTransformPointer successful" << std::endl;
    }
    
//    return registrationFactory->GetTransform();
    
    
    return registrationFactory->GetTransformVectorField();
}

-(ITKImageContainer*)transform:(ITKImage::Pointer)toAlign
                  orFunctional:(ITKImage4D::Pointer)toAlignFun
                 withReference:(ITKImage::Pointer)ref 
                transformation:(DeformationFieldType::Pointer)trans 
                    resolution:(std::vector<size_t>)res; 
{
//    if (toAlignFun.IsNotNull()) {
//        ITKImage4D::PointType toAlignFunOrigin = toAlignFun->GetOrigin();
//        std::cout << "Functional origin:" << std::endl;
//        std::cout << toAlignFunOrigin << std::endl;
//        
//        ITKImage4D::DirectionType toAlignFunDirection = toAlignFun->GetDirection();
//        std::cout << "Functional direction matrix:" << std::endl;
//        std::cout << toAlignFunDirection << std::endl;
//    }
//    if (toAlign.IsNotNull()) {
//        ITKImage::PointType toAlignOrigin = toAlign->GetOrigin();
//        std::cout << "3D origin:" << std::endl;
//        std::cout << toAlignOrigin << std::endl;
//        
//        ITKImage::DirectionType toAlignDirection = toAlign->GetDirection();
//        std::cout << "3D direction matrix:" << std::endl;
//        std::cout << toAlignDirection << std::endl;
//    }
    
    // From dotrans3d
    // init taken from constructor
    ResampleImageFilterType::Pointer resampler;
    WarpImageFilterType::Pointer warper;
    resampler = ResampleImageFilterType::New();
    warper = WarpImageFilterType::New();
    
    self->linearInterpolator = LinearInterpolatorType::New();
    self->bsplineInterpolator = BSplineInterpolatorType::New();
    self->nearestNeighborInterpolator = NearestNeighborInterpolatorType::New();
    // was in constructor originally
        
    resampler->SetNumberOfThreads(NR_THREADS);
    warper->SetNumberOfThreads(NR_THREADS);

    ITKImage::Pointer inputImage = ITKImage::New();
    ITKImage::Pointer templateImage = ref;
    ITKImage4D::Pointer fmriImage = ITKImage4D::New();
    
    ITKImage::SizeType    outputSize;
    ITKImage::SpacingType outputSpacing;
    ITKImage::SizeType fmriOutputSize;
	ITKImage::SpacingType fmriOutputSpacing;
    
    //setting up the output resolution
	if (res.size() > 0) {
		if (static_cast<unsigned int> (res.size()) < IMAGE_DIMENSION) {
			//user has specified less than 3 resolution values->sets isotrop resolution with the first typed value
			outputSpacing.Fill( static_cast<float>( res[0] ) );
		}
        
		if (res.size() >= 3 ) {
			//user has specified at least 3 values -> sets anisotrop resolution
			for (unsigned int i = 0; i < 3; i++) {
				outputSpacing[i] = res[i];
			}
		}
	} else {
		if (ref.IsNull()) {
			outputSpacing = inputImage->GetSpacing();
			outputSize = inputImage->GetLargestPossibleRegion().GetSize();
		} else {
            outputSpacing = templateImage->GetSpacing();
			outputSize = templateImage->GetLargestPossibleRegion().GetSize();
        }
	}
    
	if (toAlignFun.IsNotNull()) {
		fmriImage  = toAlignFun;
	} 
    if (toAlign.IsNotNull()) {
		inputImage = toAlign;
    }
    
    ITKImage::PointType outputOrigin;
	ITKImage::DirectionType outputDirection;
    
    if (ref.IsNull()) {
		outputDirection = inputImage->GetDirection();
		outputOrigin = inputImage->GetOrigin();
	} else {
		outputDirection = templateImage->GetDirection();
		outputOrigin = templateImage->GetOrigin();
	}
    
//    if ( trans_filename.number ) {
//		unsigned int number_trans = trans_filename.number;
//        
//		if ( number_trans > 1 ) {
//			std::cout << "More than one transform is set. This is not possible, yet!" << std::endl;
//			return EXIT_FAILURE;
//		}
//        
//		if ( number_trans == 1 ) {
//			transformFileReader->SetFileName( ( ( VStringConst * ) trans_filename.vector )[0] );
//			transformFileReader->Update();
//			itk::TransformFileReader::TransformListType *transformList = transformFileReader->GetTransformList();
//			itk::TransformFileReader::TransformListType::const_iterator ti;
//			ti = transformList->begin();
//            
//			//setting up the resample object
//			if(identity) {
//				itk::IdentityTransform<double, 3>::Pointer identityTransform = itk::IdentityTransform<double,3>::New();
//				resampler->SetTransform( identityTransform );	
//			}
//			else if ( use_inverse ) {
//				transform->SetParameters( static_cast<TransformPointer>( ( *ti ).GetPointer() )->GetInverseTransform()->GetParameters() );
//				transform->SetFixedParameters( static_cast<TransformPointer>( ( *ti ).GetPointer() )->GetInverseTransform()->GetFixedParameters() );
//				resampler->SetTransform( transform );
//			}
//            
//			else if ( !use_inverse ) {
//				resampler->SetTransform( static_cast<ConstTransformPointer> ( ( *ti ).GetPointer() ) );
//			}
//		}
//	}
   
//	if ( vtrans_filename.number ) {
//		if ( vtrans_filename.number > 1 ) {
//		    transformMerger->setNumberOfThreads(number_threads);
//			for ( size_t i = 0; i < vtrans_filename.number; i++ ) {
//				deformationFieldReader->SetFileName( ((VStringConst*) vtrans_filename.vector)[i] );
//				deformationFieldReader->UpdateLargestPossibleRegion();
//				defFieldTmp = deformationFieldReader->GetOutput();
//				transformMerger->push_back( defFieldTmp );
//				defFieldTmp->DisconnectPipeline();
//			}
//			transformMerger->merge();
//			defField->DisconnectPipeline();
//			defField = transformMerger->getTransform();
//		} else {
//			deformationFieldReader->SetFileName( ((VStringConst*) vtrans_filename.vector)[0] );
//			deformationFieldReader->Update();
//			defField = deformationFieldReader->GetOutput();
//	    }
//	}
    
    if (res.size() > 0) {
        if (ref.IsNotNull()) {
            for (size_t i = 0; i < 3; i++) {
                //output spacing = (template size / output resolution) * template resolution
                outputSize[i] = (templateImage->GetLargestPossibleRegion().GetSize()[i] / outputSpacing[i]) * templateImage->GetSpacing()[i];
            }
            std::cout << "outputSize (ref.size>0, ref!=NULL):    " << outputSize << std::endl;
            std::cout << "outputSpacing (ref.size>0, ref!=NULL): " << outputSpacing << std::endl;
        } 
        else {
            for (size_t i = 0; i < 3; i++ ) {
                //output spacing = (moving size / output resolution) * moving resolution
                if (toAlignFun.IsNotNull()) {
                    outputSize[i] = (fmriImage->GetLargestPossibleRegion().GetSize()[i] / outputSpacing[i]) * fmriImage->GetSpacing()[i];
                }
                else 
                {
                    outputSize[i] = (inputImage->GetLargestPossibleRegion().GetSize()[i] / outputSpacing[i]) * inputImage->GetSpacing()[i];
                }
                std::cout << "outputSize (ref.size==0, ref==NULL, fmri):    " << outputSize << std::endl;
                std::cout << "outputSpacing (ref.size==0, ref==NULL, fmri): " << outputSpacing << std::endl;
            }
        }
	}
    
    //setting up the interpolator
    short interpolator_type = 0;
    switch (interpolator_type) {
        case 0:
            resampler->SetInterpolator( linearInterpolator );
            warper->SetInterpolator( linearInterpolator );
            break;
        case 1:
            resampler->SetInterpolator( bsplineInterpolator );
            warper->SetInterpolator( bsplineInterpolator );
            break;
        case 2:
            resampler->SetInterpolator( nearestNeighborInterpolator );
            warper->SetInterpolator( nearestNeighborInterpolator );
            break;
	}
    
    ITKImage::PointType fmriOutputOrigin;
    ITKImage::DirectionType fmriOutputDirection;
    
    ITKImageContainer* result = NULL;
    
	if (toAlignFun.IsNotNull()) {
        TimeStepExtractionFilterType::Pointer timeStepExtractionFilter = TimeStepExtractionFilterType::New();
		timeStepExtractionFilter->SetInput(fmriImage);
        
		if (ref.IsNotNull()) {
			fmriOutputOrigin = templateImage->GetOrigin();
			fmriOutputDirection = templateImage->GetDirection();
		}
        
		for ( unsigned int i = 0; i < 3; i++ ) {
			if (res.size() > 0) {
				fmriOutputSpacing[i] = outputSpacing[i];
				fmriOutputSize[i] = outputSize[i];
			} else {
				if (ref.IsNull()) {
					fmriOutputSpacing[i] = fmriImage->GetSpacing()[i];
					fmriOutputSize[i] = fmriImage->GetLargestPossibleRegion().GetSize()[i];
				} else {
					fmriOutputSpacing[i] = templateImage->GetSpacing()[i];
					fmriOutputSize[i] = templateImage->GetLargestPossibleRegion().GetSize()[i];
				}
			}
            
			if (ref.IsNull()) {
				fmriOutputOrigin[i] = fmriImage->GetOrigin()[i];
                
				for ( unsigned int j = 0; j < 3; j++ ) {
					fmriOutputDirection[j][i] = fmriImage->GetDirection()[j][i];
				}
			}
		}
        
		if (fmriOutputSpacing[3] == 0) 
            fmriOutputSpacing[3] = 1; 
        
		if (trans.IsNotNull()) {
			warper->SetOutputDirection(fmriOutputDirection);
			warper->SetOutputOrigin(fmriOutputOrigin);
			warper->SetOutputSize(fmriOutputSize);
			warper->SetOutputSpacing(fmriOutputSpacing);
			warper->SetInput(inputImage);
            warper->SetDeformationField(trans);
		}
        
		itk::FixedArray<unsigned int, 4> layout;
		layout[0] = 1;
		layout[1] = 1;
		layout[2] = 1;
		layout[3] = 0;
		const unsigned int numberOfTimeSteps = fmriImage->GetLargestPossibleRegion().GetSize()[3];
        
		ITKImage::Pointer tileImage;
		std::cout << std::endl;
//		inputImage = ... <code using itkAdapter>
        
		ITKImage4D::DirectionType direction4D;
		for ( size_t i = 0; i < 3; i++ ) {
			for ( size_t j = 0; j < 3; j++ ) {
				direction4D[i][j] = fmriOutputDirection[i][j];
			}
		}
        
		direction4D[3][3] = 1;
        assert(direction4D[0][3] == 0);
        assert(direction4D[1][3] == 0);
        assert(direction4D[2][3] == 0);
        assert(direction4D[3][0] == 0);
        assert(direction4D[3][1] == 0);
        assert(direction4D[3][2] == 0);
        
        // Convert 4D Origin/Direction to 3D (no direct assignment possible due to ITK's templated design)
        ITKImage::PointType inputImageOrigin;
        ITKImage::DirectionType inputImageDirection;
        ITKImage4D::PointType toAlignFunOrigin = toAlignFun->GetOrigin();
        ITKImage4D::DirectionType toAlignFunDirection = toAlignFun->GetDirection();

        for (unsigned int i = 0; i < ITKImage::GetImageDimension(); i++) {
            inputImageOrigin[i] = toAlignFunOrigin[i];
            
            for (unsigned int j = 0; j < ITKImage::GetImageDimension(); j++) {
                inputImageDirection[i][j] = toAlignFunDirection[i][j];
            }
        }
        
        ITKImage::Pointer tmpImage = ITKImage::New();
        TileImageFilterType::Pointer tileImageFilter = TileImageFilterType::New();
        
        std::cout << "inputImageOrigin" << std::endl;
        std::cout << inputImageOrigin << std::endl;
        std::cout << "inputImageDirection:" << std::endl;
        std::cout << inputImageDirection << std::endl;
        
		for (unsigned int timestep = 0; timestep < numberOfTimeSteps; timestep++) {
			std::cout << "Resampling timestep: " << timestep << "...\r" << std::flush;
			timeStepExtractionFilter->SetRequestedTimeStep(timestep);
			timeStepExtractionFilter->Update();
			tmpImage = timeStepExtractionFilter->GetOutput();
			tmpImage->SetDirection(inputImageDirection);
			tmpImage->SetOrigin(inputImageOrigin);
            
			if (trans.IsNotNull()) {
				warper->SetInput(tmpImage);
				warper->Update();                      // Original lipsia function call
//                warper->UpdateLargestPossibleRegion(); // Modified function call to avoid SIGABRT
				tileImage = warper->GetOutput();
			}
            
			tileImage->Update();
			tileImage->DisconnectPipeline();
			tileImageFilter->PushBackInput(tileImage);
		}
        
		tileImageFilter->SetLayout(layout);
		tileImageFilter->GetOutput()->SetDirection(direction4D);
		tileImageFilter->Update();
		
//        resultImg = [toAlign convertFromITKImage4D:tileImageFilter->GetOutput()];
        result = new ITKImageContainer(tileImageFilter->GetOutput());

	} else {
        // No fmri
//		if ( vtrans_filename or trans_filename.number > 1 && !identity ) {
        if (trans.IsNotNull()) {
			warper->SetOutputDirection(outputDirection);
			warper->SetOutputOrigin(outputOrigin);
			warper->SetOutputSize(outputSize);
			warper->SetOutputSpacing(outputSpacing);
			warper->SetInput(inputImage);
            
            warper->SetDeformationField(trans);
			      
			warper->Update();
            
            ITKImage::Pointer output = warper->GetOutput();
            
//            typedef itk::ImageFileWriter<ITKImage> ITKWriter;
//            ITKWriter::Pointer imageWriter = ITKWriter::New();
//            imageWriter->SetFileName("/tmp/RORegistrationTestImage.nii");
//            imageWriter->SetInput(output);
//            imageWriter->Update();

//            NSLog(@"### START Converting ITK2Isis");
//			resultImg = [toAlign convertFromITKImage:output];
            result = new ITKImageContainer(output);
//            NSLog(@"### END Converting ITK2Isis");
		}
    }
    
//    isis::data::IOFactory::write( imgList, "/tmp/RORegIsisFix.nii", "", "" );
    
    return result;
}

@end
