inlets = 5
outlets = 5

var mux = 0;
var muy = 0;
var varx = 1;
var vary = 1;
var cov = 0;

var RESOLUTION = 21;


var outMat = new JitterMatrix(1, "float32", 21, 21);

function loadbang(){
	
}

function msg_float(f){
	switch(inlet){
	case 0:
		mux = f;
		break;
	case 1:
		muy = -f;
		break;
	case 2:
		varx = f;
		break;
	case 3:
		vary = f;
		break;
	case 4:
		cov = -f;
		break;
	}
	
	
	
	outlet(2, varx);
	outlet(3, vary);
	outlet(4, cov);
	bang();
}

function bang(){
	var determinant = varx * vary - cov * cov;
	
	var normalizer = Math.sqrt(determinant) * 2 * Math.PI;
	
	
	var range = (RESOLUTION / 2)
	for (var i = 0; i <= RESOLUTION; i++){
		for (var j = 0; j <= RESOLUTION; j++){
			var xindex = ((i - range) / range) - mux;
			var yindex = ((j - range) / range) - muy;
			// XEX^t
			var extop = xindex * vary - yindex * cov;
			var exbottom = yindex * varx - xindex * cov;
			
			var xex = xindex * extop + yindex * exbottom;
			xex /= (varx * vary - cov * cov)
			var val = Math.exp(-0.5 * xex) / normalizer;
			
			outMat.setcell2d(i, j, val)
		}
	}
	
	outlet(0, "jit_matrix", outMat.name);
}

function mvGaussPDF(){}