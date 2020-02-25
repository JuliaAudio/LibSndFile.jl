# convenience function to calculate the mean-squared error
function mse(arr1::AbstractArray, arr2::AbstractArray)
    if size(arr1) != size(arr2)
        throw(DimensionMismatch("Got $(size(arr1)) and $(size(arr2))"))
    end
    N = length(arr1)
    err = 0.0
    for i in 1:N
        err += (arr2[i] - arr1[i])^2
    end
    err /= N
end
