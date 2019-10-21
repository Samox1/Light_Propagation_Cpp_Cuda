#include <iostream>
#include <fstream>
#include <stdio.h>
#include <math.h>
#include <complex>
#include <cmath>
#include <cuda_runtime.h>
#include <cuda_runtime_api.h>
#include <cufft.h>
//#include <omp.h>
//#include <mpi.h>

using namespace std;

const std::complex<double> i1(0, 1);


__global__ void multiplyElementwise(cufftDoubleComplex* f0, cufftDoubleComplex* f1, int size)
{
    const int i = blockIdx.x*blockDim.x + threadIdx.x;
    if (i < size)
    {
        double a, b, c, d;
        a = f0[i].x;
        b = f0[i].y;
        c = f1[i].x;
        d = f1[i].y;
        f0[i].x = a*c - b*d;
        f0[i].y = a*d + b*c;
    }
}


// void u_in_in_big(double* u_in, cufftDoubleComplex* data, int NX, int NY, int multi);
// void h_z(double lam, double z, double k, double sampling, int NX, int NY, cufftDoubleComplex* h_z_cutab);
// void Q_roll(cufftDoubleComplex* u_in_fft, cufftDoubleComplex* data, int NX, int NY);
// void amplitude_print(cufftDoubleComplex* u_in_fft, int NX, int NY, FILE* fp);
// int FFT_Z2Z(cufftDoubleComplex* dData, int NX, int NY);
// int IFFT_Z2Z(cufftDoubleComplex* dData, int NX, int NY);



// ----------------------------------------------------------------------------------------------------------------------------------------------- //
// --- Functions --- Functions --- Functions --- Functions --- Functions --- Functions --- Functions --- Functions --- Functions --- Functions --- //
// ----------------------------------------------------------------------------------------------------------------------------------------------- //

void u_in_in_big(double* u_in, cufftDoubleComplex* data, int NX, int NY, int multi)
{
	for(int ii=0; ii < NY ; ii++)
	{
		for(int jj=0; jj < NX ; jj++)
		{
			data[ii*NX+jj].x = 0;
			data[ii*NX+jj].y = 0;
		}
	}

	for(int ii=0; ii < (int)NY/multi ; ii++)
	{
		for(int jj=0; jj < (int)NX/multi ; jj++)
		{
			data[(ii*NX+jj)+(NX*NY*(multi-1)/(multi*2)+NX*(multi-1)/(multi*2))].x = u_in[ii*(NX/multi)+jj];
		}
	}
}


void hz(double lam, double z, double k, double sampling, int NX, int NY, cufftDoubleComplex* hz_cutab)
{
	std::complex<double>* hz_tab;
	hz_tab = (std::complex<double> *) malloc ( sizeof(std::complex<double>)* NX * NY);

	double fi = 0;
	double teta = 0;
	double lam_z = 0;

	fi = k * z;
	teta = k / (2.0 * z);
	lam_z = lam * z;
	double quad = 0.0;
	double teta1 = 0.0;	
	

	for(int iy=0; iy < NY; iy++)
	{
		//printf("\n");
		for(int ix=0; ix < NX ; ix++)
		{
			quad = pow(((double)ix-((double)NX/2.0))*sampling, 2) + pow(((double)iy-((double)NY/2.0))*sampling, 2);
			teta1 = teta * quad;
			//hz_tab[iy*NX+ix] = std::exp(i*fi) * std::exp(i*teta1)/(i*lam_z);
			hz_tab[iy*NX+ix] = std::exp(i1*fi) * std::exp(i1*teta1)/(i1*lam_z);
			hz_cutab[iy*NX+ix].x = hz_tab[iy*NX+ix].real();
			hz_cutab[iy*NX+ix].y = hz_tab[iy*NX+ix].imag();
			//printf("%.2f\t", hz_cutab[iy*NX+ix].x);
		}
	}	
	free(hz_tab);
}


void Qroll(cufftDoubleComplex* u_in_fft, cufftDoubleComplex* data, int NX, int NY)
{
	for(int iy=0; iy<(NY/4); iy++)	//Petla na przepisanie tablicy koncowej
	{
		for(int jx=0; jx<(NX/4); jx++)
		{
			u_in_fft[(NX/2*NY/4+NY/4)+(jx+iy*NX/2)] = data[iy*(NX)+jx];		// Q1 -> Q4
			u_in_fft[(jx+NX/4)+(iy*NX/2)] = data[(iy*(NX)+jx)+(NX*NY*3/4)];		// Q3 -> Q2
			u_in_fft[(jx)+(iy*NX/2)] = data[((iy*NX)+jx)+(NX*3/4+NX*NY*3/4)];	// Q4 -> Q1
			u_in_fft[(jx)+(iy*NX/2)+NX*NY/2/4] = data[((iy*NX)+jx)+(NX*3/4)];	// Q2 -> Q3
		}
	}
}

void amplitude_print(cufftDoubleComplex* u_in_fft, int NX, int NY, FILE* fp)
{
	// --- Przeliczanie Amplitudy --- //

	for(int ii=0; ii<(NX*NY/4); ii++)
	{	
		u_in_fft[ii].x = sqrt(pow(u_in_fft[ii].x, 2) + pow(u_in_fft[ii].y, 2));
	}
	
	double mini_data = u_in_fft[0].x;
	
	for(int ii=0; ii<(NX*NY/4); ii++)
	{		
		if (u_in_fft[ii].x < mini_data){ mini_data = u_in_fft[ii].x; }
	}
	
	double max_data = u_in_fft[0].x;
	mini_data = -mini_data;
	
	for(int ii=0; ii<(NX*NY/4); ii++)
	{		
		u_in_fft[ii].x = u_in_fft[ii].x + mini_data;
		if (u_in_fft[ii].x > max_data) { max_data = u_in_fft[ii].x; }
	}

	for(int ii=0; ii<(NX*NY/4); ii++)
	{	
		if (ii%(NX/2) == 0){fprintf (fp,"\n");}
		u_in_fft[ii].x = u_in_fft[ii].x / max_data * 255.0;
		fprintf (fp,"%.0f\t", u_in_fft[ii].x);
	}
}
																					// --- ERROR --- Undefined Reference to 'cufftPlan2D' & 'cufftExecZ2Z' & 'cufftDestroy'
																					// --- Nie widzi CUFFT z Cuda
																					// --- Nie było flagi -lcufft podczas kompilacji - jej...
int FFT_Z2Z(cufftDoubleComplex* dData, int NX, int NY)
{
	// Create a 2D FFT plan. 
	int err = 0;
	cufftHandle plan1;
	if (cufftPlan2d(&plan1, NX, NY, CUFFT_Z2Z) != CUFFT_SUCCESS){
		fprintf(stderr, "CUFFT Error: Unable to create plan\n");
		err = -1;	
	}

	if (cufftExecZ2Z(plan1, dData, dData, CUFFT_FORWARD) != CUFFT_SUCCESS){
		fprintf(stderr, "CUFFT Error: Unable to execute plan\n");
		err = -1;		
	}

	if (cudaDeviceSynchronize() != cudaSuccess){
  		fprintf(stderr, "Cuda error: Failed to synchronize\n");
   		err = -1;
	}	
	
	cufftDestroy(plan1);
	return err;
}

int IFFT_Z2Z(cufftDoubleComplex* dData, int NX, int NY)
{
	// Create a 2D FFT plan.
	int err = 0; 
	cufftHandle plan1;
	if (cufftPlan2d(&plan1, NX, NY, CUFFT_Z2Z) != CUFFT_SUCCESS){
		fprintf(stderr, "CUFFT Error: Unable to create plan\n");
		err = -1;	
	}

	if (cufftExecZ2Z(plan1, dData, dData, CUFFT_INVERSE) != CUFFT_SUCCESS){
		fprintf(stderr, "CUFFT Error: Unable to execute plan\n");
		err = -1;		
	}

	if (cudaDeviceSynchronize() != cudaSuccess){
  		fprintf(stderr, "Cuda error: Failed to synchronize\n");
   		err = -1;
	}

	cufftDestroy(plan1);	
	return err;
}


void BMP_Save(cufftDoubleComplex* u_out, int NX, int NY, FILE* fp)
{
  // --- SAVE BMP FILE --- //
  uint8_t colorIndex = 0;
  uint16_t color = 0;
  unsigned int headers[13];
  int extrabytes;
  int paddedsize;
  int x = 0; 
  int y = 0; 
  int n = 0;
  int red = 0;
  int green = 0;
  int blue = 0;
  
  int WIDTH = NX;
  int HEIGHT = NY;

  extrabytes = 4 - ((WIDTH * 3) % 4);                 // How many bytes of padding to add to each
                                                    // horizontal line - the size of which must
                                                    // be a multiple of 4 bytes.
  if (extrabytes == 4)
    extrabytes = 0;

  paddedsize = ((WIDTH * 3) + extrabytes) * HEIGHT;

// Headers...
// Note that the "BM" identifier in bytes 0 and 1 is NOT included in these "headers".

  headers[0]  = paddedsize + 54;      // bfSize (whole file size)
  headers[1]  = 0;                    // bfReserved (both)
  headers[2]  = 54;                   // bfOffbits
  headers[3]  = 40;                   // biSize
  headers[4]  = WIDTH;                // biWidth
  headers[5]  = HEIGHT;               // biHeight

// Would have biPlanes and biBitCount in position 6, but they're shorts.
// It's easier to write them out separately (see below) than pretend
// they're a single int, especially with endian issues...

  headers[7]  = 0;                    // biCompression
  headers[8]  = paddedsize;           // biSizeImage
  headers[9]  = 0;                    // biXPelsPerMeter
  headers[10] = 0;                    // biYPelsPerMeter
  headers[11] = 0;                    // biClrUsed
  headers[12] = 0;                    // biClrImportant

// outfile = fopen(filename, "wb");

  //File file = fopen("test.bmp", "wb");
  if (!fp) {
    Serial.println("There was an error opening the file for writing");
    //return;
  }else{

// Headers begin...
// When printing ints and shorts, we write out 1 character at a time to avoid endian issues.

	fprintf(fp, "BM");

  for (n = 0; n <= 5; n++)
  { 
    fprintf(fp, "%c", headers[n] & 0x000000FF);
    fprintf(fp, "%c", (headers[n] & 0x0000FF00) >> 8);
    fprintf(fp, "%c", (headers[n] & 0x00FF0000) >> 16);
    fprintf(fp, "%c", (headers[n] & (unsigned int) 0xFF000000) >> 24);
  }

// These next 4 characters are for the biPlanes and biBitCount fields.

  fprintf(fp, "%c", 1);
  fprintf(fp, "%c", 0);
  fprintf(fp, "%c", 24);
  fprintf(fp, "%c", 0);

  for (n = 7; n <= 12; n++)
  {
    fprintf(fp, "%c", headers[n] & 0x000000FF);
    fprintf(fp, "%c", (headers[n] & 0x0000FF00) >> 8);
    fprintf(fp, "%c", (headers[n] & 0x00FF0000) >> 16);
    fprintf(fp, "%c", (headers[n] & (unsigned int) 0xFF000000) >> 24);
  }

  	// --- Przeliczanie Amplitudy --- //

	for(int ii=0; ii<(NX*NY/4); ii++)
	{	
		u_out[ii].x = sqrt(pow(u_out[ii].x, 2) + pow(u_out[ii].y, 2));
	}
	
	double mini_data = u_in_fft[0].x;
	
	for(int ii=0; ii<(NX*NY/4); ii++)
	{		
		if (u_in_fft[ii].x < mini_data){ mini_data = u_in_fft[ii].x; }
	}
	
	double max_data = u_in_fft[0].x;
	mini_data = -mini_data;
	
	for(int ii=0; ii<(NX*NY/4); ii++)
	{		
		u_in_fft[ii].x = u_in_fft[ii].x + mini_data;
		if (u_in_fft[ii].x > max_data) { max_data = u_in_fft[ii].x; }
	}

	for(int ii=0; ii<(NX*NY/4); ii++)
	{	
		if (ii%(NX/2) == 0){fprintf (fp,"\n");}
		u_in_fft[ii].x = u_in_fft[ii].x / max_data * 255.0;
		fprintf (fp,"%.0f\t", u_in_fft[ii].x);
	}


// Headers done, now write the data...

  for (y = HEIGHT - 1; y >= 0; y--)     // BMP image format is written from bottom to top...
  {
    for (x = 0; x <= WIDTH - 1; x++)
    {
      // --- Read ColorIndex corresponding to Pixel Temperature --- //
      colorIndex = map(mlx90640To[x+(32*y)], MinTemp-5.0, MaxTemp+5.0, 0, 255);
      colorIndex = constrain(colorIndex, 0, 255);
      color = camColors[colorIndex];
      
      // --- Converts 4 Digits HEX to RGB565 --- //
      // uint8_t r = ((color >> 11) & 0x1F);
      // uint8_t g = ((color >> 5) & 0x3F);
      // uint8_t b = (color & 0x1F);

      // --- Converts 4 Digits HEX to RGB565 -> RGB888 --- //
      red = ((((color >> 11) & 0x1F) * 527) + 23) >> 6;
      green = ((((color >> 5) & 0x3F) * 259) + 33) >> 6;
      blue = (((color & 0x1F) * 527) + 23) >> 6;

      // --- RGB range from 0 to 255 --- //
      if (red > 255) red = 255; if (red < 0) red = 0;
      if (green > 255) green = 255; if (green < 0) green = 0;
      if (blue > 255) blue = 255; if (blue < 0) blue = 0;

      // Also, it's written in (b,g,r) format...

      file.printf("%c", blue);
      file.printf("%c", green);
      file.printf("%c", red);
    }
    if (extrabytes)      // See above - BMP lines must be of lengths divisible by 4.
    {
      for (n = 1; n <= extrabytes; n++)
      {
         file.printf("%c", 0);
      }
    }
  }

  file.close();
  Serial.println("File Closed");
  }         // --- END SAVING BMP FILE --- //
}


/*
 * start program: ./cudaOpenMP Tablica-1024x1024.txt 1024 1024 1 500.0 633.0
 * start program: ./cudaOpenMP plik_z_przezroczem.txt COL ROW Multiply Odleglosc_Z_mm Dl_fali_Lambda_nm
 */


// --- Main Part --- MAIN --- MAIN --- MAIN --- MAIN --- MAIN --- MAIN --- MAIN --- MAIN --- MAIN --- MAIN --- MAIN --- MAIN --- MAIN --- MAIN --- MAIN --- //

int main(int argc, char *argv[])
{

    cout << "Welcome to CUDA test" << endl;

    int COL = atoi(argv[2]);
	int ROW = atoi(argv[3]);

	//int COL = 1024;
	//int ROW = 1024;
	//double u_in[ROW*COL];
	//cout << "DEBUG" << endl;

	double* u_in;
	u_in = (double *) malloc ( sizeof(double)* COL * ROW);

	cout << "WELCOME" << " | " << argv[0] << " | " << argv[1] << " | " << argv[2] << " | " << argv[3] << " | " << atoi(argv[4]) << " | " << atoi(argv[5]) << " | " << atoi(argv[6]) << endl;

	ifstream inputFile;
    inputFile.open(argv[1]);

    if (inputFile)
	{
		cout << "Import file: " << argv[1] << endl;
		int i,j = 0;
		for (i = 0; i < ROW; i++)
		{
			for (j = 0; j < COL; j++)
			{
				inputFile >> u_in[i*ROW+j];
			}
		}
		cout << "Import file - complete" << endl;
	} else {
		cout << "Error opening the file.\n";
	}
	inputFile.close();


	int multi = atoi(argv[4]);
	int NX = COL*multi;
	int NY = ROW*multi;

	// --- Przeliczenie hz --- //

	double sampling = 10.0 * pow(10.0, (-6)); 		// Sampling = 10 micro
	double lam = atof(argv[6]) * (pow(10.0,(-9))); 			// Lambda = 633 nm
	double k = 2.0 * M_PI / lam;					// Wektor falowy k
	double z_in = atof(argv[5])*(pow(10.0,(-3)));	// Odleglosc propagacji = 0,5 m
	double z_out = 1000.0*(pow(10.0,(-3)));     	// Koniec odległości propagacji = 1 m
	double z_delta = 50.0*(pow(10.0,(-3)));     	// Skok odległości = 0,05 m
	//double z = z_in+(ip*z_delta);             	// Odległość Z dla każdego wątku MPI
    double z = z_in;

    printf("k = %.1f | lam = %.1f nm | z = %.4f m | \n", k, lam*(pow(10.0,(9))), z);

	// --- FFT tablicy wejsciowej --- //
	cufftDoubleComplex* data;
	data = (cufftDoubleComplex *) malloc ( sizeof(cufftDoubleComplex)* NX * NY);

	cufftDoubleComplex* dData;
	cudaMalloc((void **) &dData, sizeof(cufftDoubleComplex)* NX * NY);
	
	if (cudaGetLastError() != cudaSuccess){
		fprintf(stderr, "Cuda error: Failed to allocate\n");
		return -1;
	}
	
	size_t pitch1;

	u_in_in_big(u_in, data, NX, NY, multi);
	
	// --- Liczenie U_in = FFT{u_in} --- //
 	cudaMallocPitch(&dData, &pitch1, sizeof(cufftDoubleComplex)*NX, NY);
	cudaMemcpy2D(dData,pitch1,data,sizeof(cufftDoubleComplex)*NX,sizeof(cufftDoubleComplex)*NX,NX,cudaMemcpyHostToDevice);
	
	if (cudaGetLastError() != cudaSuccess){
		fprintf(stderr, "Cuda error: Failed to allocate\n");
		return -1;	
	}
	
	if (FFT_Z2Z(dData, NX, NY) == -1) { 
		return -1; 
	}
	cudaMemcpy(data, dData, sizeof(cufftDoubleComplex)*NX*NY, cudaMemcpyDeviceToHost);
		
	
	// --- Liczenie hz --- //
	cufftDoubleComplex* hz_tab;
	hz_tab = (cufftDoubleComplex *) malloc ( sizeof(cufftDoubleComplex)* NX * NY);
	hz(lam, z, k, sampling, NX, NY, hz_tab);
			

	// --- Liczenie hz = FFT{hz_tab} --- //
	cufftDoubleComplex* hz;
	cudaMalloc((void **) &hz, sizeof(cufftDoubleComplex)* NX * NY);

	size_t pitch2;
 	cudaMallocPitch(&hz, &pitch2, sizeof(cufftDoubleComplex)*NX, NY);
	cudaMemcpy2D(hz,pitch2,hz_tab,sizeof(cufftDoubleComplex)*NX,sizeof(cufftDoubleComplex)*NX,NX,cudaMemcpyHostToDevice);

	if(cudaGetLastError() != cudaSuccess){
		fprintf(stderr, "Cuda error: Failed to allocate\n");
		return -1;	
	}

	if (FFT_Z2Z(hz, NX, NY) == -1) { 
		return -1; 
	}

	// --- Do the actual multiplication --- //
	multiplyElementwise<<<NX*NY, 1>>>(dData, hz, NX*NY);
	

	// --- Liczenie u_out = iFFT{dData = U_OUT} --- //
	if(IFFT_Z2Z(dData, NX, NY) == -1) { return -1; }

	cudaMemcpy(data, dData, sizeof(cufftDoubleComplex)*NX*NY, cudaMemcpyDeviceToHost);

	//printf( "\nCUFFT vals: \n");
	

	// --- ROLL cwiartek, zeby wszystko sie zgadzalo na koniec --- //

	cufftDoubleComplex* u_out;
	u_out = (cufftDoubleComplex *) malloc (sizeof(cufftDoubleComplex)* NX/2 * NY/2);

	Qroll(u_out, data, NX, NY);

	// --- Przeliczanie Amplitudy --- //

	char filename[128];
	snprintf ( filename, 128, "result_z_%.5lf.BMP", z );
	FILE* fp = fopen(filename,"wb");

	amplitude_print(u_out, NX, NY, fp);

	fclose(fp);

	// --- Zwalnianie pamieci --- //

	cudaFree(u_out);
	cudaFree(data);
	cudaFree(dData);
	cudaFree(hz_tab);
	cudaFree(hz);

	free(u_in);

	//cout << "DEBUG" << endl;

	return 0;
}


