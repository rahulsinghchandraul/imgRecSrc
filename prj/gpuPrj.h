
#ifndef __GPUPRJ_H__
#define __GPUPRJ_H__

#include <stddef.h>
#include <float.h>
#define EPS (1e-8)      // need to justify

#define EXE_TIME 1
#define EXE_PROF 0
#define DEBUG   0
#define SHOWIMG  1
#define GPU 1

#define DIM   1024

// for forward projection

#define THRD_SZ 64
#define LYR_BLK 1

// for backprojection
#define TILE_SZ 8
#define ANG_BLK 1

//#define MAX(x,y) ((x) > (y) ? (x) : (y))
//#define MIN(x,y) ((x) < (y) ? (x) : (y))
#define RENEW_MEM (1<<1)
#define FWD_BIT (1)

#define HANDLE_ERROR( err ) (HandleError( err, __FILE__, __LINE__ ))

typedef float ft;

struct prjConf {
    int n; /* number of rows and cols of input image */
    int prjWidth;       /* # of elements per projection */
    int np;     /* number of projections in need */
    int prjFull;       // # of projections in 360 degree
    float dSize;       // size of a single detector
    float effectiveRate;       // effective area rate of the detector

    float d;   // distance from rotation center to X-ray source in pixel
    // set d be FLT_MAX for parallel projection

    char fwd;    /* To indicate forward projection by 1 and backward by 0 */

    int imgSize;
    int sinoSize;
#if GPU
    dim3 fGrid, fThread, bGrid, bThread;
#endif
};

struct cpuPrjConf{
    int nc, nr; /* number of rows and cols of input image */
    int prjWidth;       /* # of elements per projection */
    int np;     /* number of projections in need */
    int prjFull;       // # of projections in 360 degree
    float dSize;       // size of a single detector
    float effectiveRate;       // effective area rate of the detector

    float d;   // distance from rotation center to X-ray source in pixel
    // set d be FLT_MAX for parallel projection

    char fwd;    /* To indicate forward projection by 1 and backward by 0 */

    int imgSize;
    int sinoSize;

    int rayDrive; // if true, angle, prj and either row or col Step will be used
    // if false, angle, row and col Steps can be used for multi thread programming
    int angleStep;
    int prjStep;
    int rowStep;
    int colStep;
    int sec;
    int nthreadx;
    int nthready;

    int nthread;
};

void setup(int n, int prjWidth, int np, int prjFull, ft dSize, ft effectiveRate, ft d);
void showSetup(void);
int gpuPrj(ft* img, ft* sino, char cmd);

#endif

